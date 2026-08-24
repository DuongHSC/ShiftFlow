// ShiftFlow — Domain Layer
// Services/ShiftConfigurationService.swift
//
// TASK-SETTINGS-001: Shift & schedule-rule configuration management.
//
// Stores user-editable ShiftDefinition and ScheduleRule configuration and
// enforces validation. This is the SINGLE place that mutates configuration.
//
// CRITICAL INVARIANT:
// Editing configuration here NEVER touches existing WorkDay snapshots.
// This service does not iterate WorkDays and does not call ShiftResolver.
// It only stores configuration used for FUTURE resolution.
//
// The shift CODE is stable (used by WorkDay.shiftID/shiftCode) and cannot
// be changed via edits — only name/times/break/active state are editable.

import Foundation

// MARK: - Model Edit Helpers (non-mutating)

public extension ShiftDefinition {
    /// Returns a copy with edited fields. The `code` and `id` are preserved
    /// (stable identity). `modifiedAt` is refreshed.
    func withEdits(
        name: String? = nil,
        startHour: Int? = nil, startMinute: Int? = nil,
        endHour: Int? = nil, endMinute: Int? = nil,
        breakStartHour: Int? = nil, breakStartMinute: Int? = nil,
        breakEndHour: Int? = nil, breakEndMinute: Int? = nil,
        isActive: Bool? = nil,
        modifiedAt: Date = Date()
    ) -> ShiftDefinition {
        ShiftDefinition(
            id: id,
            code: code, // stable — never changes
            name: name ?? self.name,
            startHour: startHour ?? self.startHour,
            startMinute: startMinute ?? self.startMinute,
            endHour: endHour ?? self.endHour,
            endMinute: endMinute ?? self.endMinute,
            breakStartHour: breakStartHour ?? self.breakStartHour,
            breakStartMinute: breakStartMinute ?? self.breakStartMinute,
            breakEndHour: breakEndHour ?? self.breakEndHour,
            breakEndMinute: breakEndMinute ?? self.breakEndMinute,
            isActive: isActive ?? self.isActive,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

public extension ScheduleRule {
    /// Returns a copy with edited fields. `id` and `shiftID` are preserved.
    func withEdits(
        startDayOfMonth: Int? = nil,
        endDayOfMonth: Int? = nil,
        startHour: Int? = nil, startMinute: Int? = nil,
        endHour: Int? = nil, endMinute: Int? = nil,
        breakStartHour: Int? = nil, breakStartMinute: Int? = nil,
        breakEndHour: Int? = nil, breakEndMinute: Int? = nil,
        priority: Int? = nil,
        isActive: Bool? = nil
    ) -> ScheduleRule {
        ScheduleRule(
            id: id,
            shiftID: shiftID,
            startDayOfMonth: startDayOfMonth ?? self.startDayOfMonth,
            endDayOfMonth: endDayOfMonth ?? self.endDayOfMonth,
            startHour: startHour ?? self.startHour,
            startMinute: startMinute ?? self.startMinute,
            endHour: endHour ?? self.endHour,
            endMinute: endMinute ?? self.endMinute,
            breakStartHour: breakStartHour ?? self.breakStartHour,
            breakStartMinute: breakStartMinute ?? self.breakStartMinute,
            breakEndHour: breakEndHour ?? self.breakEndHour,
            breakEndMinute: breakEndMinute ?? self.breakEndMinute,
            priority: priority ?? self.priority,
            isActive: isActive ?? self.isActive
        )
    }
}

// MARK: - Configuration Store

/// Persists shift definitions and schedule rules.
/// Concrete implementations (in-memory for tests, SwiftData-backed for the app)
/// live outside the domain.
public protocol ShiftConfigurationStore: AnyObject {
    func allDefinitions() -> [ShiftDefinition]
    func allRules() -> [ScheduleRule]
    func upsertDefinition(_ def: ShiftDefinition)
    func upsertRule(_ rule: ScheduleRule)
    func replaceAll(definitions: [ShiftDefinition], rules: [ScheduleRule])
}

/// A simple in-memory configuration store (default for app + tests).
public final class InMemoryShiftConfigurationStore: ShiftConfigurationStore {
    private var definitions: [UUID: ShiftDefinition] = [:]
    private var rules: [UUID: ScheduleRule] = [:]

    public init(seed: Bool = true) {
        if seed {
            for def in ShiftSeedProvider.allDefaultShifts() { definitions[def.id] = def }
            for rule in ShiftSeedProvider.allDefaultRules() { rules[rule.id] = rule }
        }
    }

    public func allDefinitions() -> [ShiftDefinition] {
        definitions.values.sorted { $0.code < $1.code }
    }
    public func allRules() -> [ScheduleRule] {
        Array(rules.values)
    }
    public func upsertDefinition(_ def: ShiftDefinition) { definitions[def.id] = def }
    public func upsertRule(_ rule: ScheduleRule) { rules[rule.id] = rule }
    public func replaceAll(definitions defs: [ShiftDefinition], rules newRules: [ScheduleRule]) {
        definitions.removeAll(); rules.removeAll()
        for d in defs { definitions[d.id] = d }
        for r in newRules { rules[r.id] = r }
    }
}

// MARK: - Configuration Service

/// Manages shift/schedule-rule configuration.
///
/// This service:
/// - stores configuration (validated)
/// - performs idempotent first-run seeding
/// - resets to defaults
/// - provides lookup for FUTURE resolution
///
/// It NEVER modifies existing WorkDay snapshots and NEVER resolves schedules.
public final class ShiftConfigurationService {

    private let store: ShiftConfigurationStore

    public init(store: ShiftConfigurationStore) {
        self.store = store
    }

    // MARK: - Read

    public func allShifts() -> [ShiftDefinition] { store.allDefinitions() }
    public func allRules() -> [ScheduleRule] { store.allRules() }

    public func shift(withCode code: String) -> ShiftDefinition? {
        store.allDefinitions().first { $0.code.uppercased() == code.uppercased() }
    }

    /// Active shifts selectable for NEW WorkDay creation.
    public func selectableShifts() -> [ShiftDefinition] {
        store.allDefinitions().filter { $0.isActive }
    }

    // MARK: - Edit Shift

    /// Updates a shift definition after validation.
    ///
    /// - Throws: `ShiftConfigurationError` if invalid or not found.
    /// - Note: Does NOT touch existing WorkDays.
    public func updateShift(_ updated: ShiftDefinition) throws {
        // Must exist (by id).
        guard store.allDefinitions().contains(where: { $0.id == updated.id }) else {
            throw ShiftConfigurationError.notFound
        }
        // Code must remain unique and unchanged (stable identity).
        let duplicate = store.allDefinitions().contains {
            $0.id != updated.id && $0.code.uppercased() == updated.code.uppercased()
        }
        if duplicate { throw ShiftConfigurationError.duplicateCode(updated.code) }

        try ShiftConfigurationValidator.validateDefinition(updated)
        store.upsertDefinition(updated)
    }

    /// Enables/disables a shift by code. Historical WorkDays are unaffected.
    public func setShiftActive(code: String, isActive: Bool) throws {
        guard let existing = shift(withCode: code) else {
            throw ShiftConfigurationError.notFound
        }
        let updated = existing.withEdits(isActive: isActive)
        store.upsertDefinition(updated)
    }

    // MARK: - Edit Rule

    /// Updates a schedule rule after validation.
    public func updateRule(_ updated: ScheduleRule) throws {
        guard store.allRules().contains(where: { $0.id == updated.id }) else {
            throw ShiftConfigurationError.notFound
        }
        try ShiftConfigurationValidator.validateRule(updated)
        store.upsertRule(updated)
    }

    /// Enables/disables a rule. When disabled, resolution uses the normal schedule.
    public func setRuleActive(id: UUID, isActive: Bool) throws {
        guard let existing = store.allRules().first(where: { $0.id == id }) else {
            throw ShiftConfigurationError.notFound
        }
        store.upsertRule(existing.withEdits(isActive: isActive))
    }

    // MARK: - Seeding (idempotent)

    /// Seeds any missing default definitions/rules WITHOUT overwriting existing ones.
    ///
    /// Preserves user customization: only definitions/rules whose IDs are not
    /// already present are added.
    public func seedIfNeeded() {
        let existingDefIDs = Set(store.allDefinitions().map { $0.id })
        for def in ShiftSeedProvider.shiftsToSeed(existingIDs: existingDefIDs) {
            store.upsertDefinition(def)
        }
        let existingRuleIDs = Set(store.allRules().map { $0.id })
        for rule in ShiftSeedProvider.rulesToSeed(existingIDs: existingRuleIDs) {
            store.upsertRule(rule)
        }
    }

    // MARK: - Reset

    /// Restores C1–C5 and the C5 day 10–20 rule to defaults.
    ///
    /// CRITICAL: This does NOT touch existing WorkDays. It only replaces the
    /// configuration used for FUTURE resolution.
    public func resetToDefaults() {
        store.replaceAll(
            definitions: ShiftSeedProvider.allDefaultShifts(),
            rules: ShiftSeedProvider.allDefaultRules()
        )
    }

    // MARK: - Lookup (for future resolution)

    /// Lookup used by WorkDay creation / import. Returns nil for OFF/unknown/inactive.
    public func lookup(_ code: String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? {
        let normalized = code.uppercased()
        guard normalized != "OFF",
              let def = shift(withCode: normalized) else {
            return nil
        }
        let rules = store.allRules().filter { $0.shiftID == def.id }
        return (def, rules)
    }
}
