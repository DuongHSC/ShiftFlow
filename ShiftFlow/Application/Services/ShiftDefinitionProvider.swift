// ShiftFlow — Application Layer
// Services/ShiftDefinitionProvider.swift
//
// TASK-INTEGRATION-001: Provides shift definitions and their schedule rules.
// TASK-SETTINGS-001: Now backed by ShiftConfigurationService so that
// configuration edits affect FUTURE WorkDay creation/resolution.
//
// Bridges shift-code lookups to ShiftDefinition + ScheduleRule for the
// WorkDayService / import pipeline.
//
// IMPORTANT: This provider affects only FUTURE resolution. Existing WorkDay
// snapshots are never modified by configuration changes.

import Foundation
import ShiftFlowDomain

/// Provides shift definitions and rules for the given shift code.
///
/// Backed by `ShiftConfigurationService`. If no service is provided, falls
/// back to the seeded defaults (used by lightweight callers/tests).
public struct ShiftDefinitionProvider {

    private let configurationService: ShiftConfigurationService?

    /// Fallback seed data (used only when no configuration service is provided).
    private let seededByCode: [String: ShiftDefinition]
    private let seededC5Rules: [ScheduleRule]

    public init(configurationService: ShiftConfigurationService? = nil) {
        self.configurationService = configurationService

        var map: [String: ShiftDefinition] = [:]
        for def in ShiftSeedProvider.allDefaultShifts() {
            map[def.code] = def
        }
        self.seededByCode = map
        self.seededC5Rules = ShiftSeedProvider.allDefaultRules()
    }

    /// Looks up a shift definition and its applicable rules by code.
    ///
    /// - Parameter code: Shift code ("C1"–"C5"). "OFF" returns nil (no WorkDay).
    /// - Returns: The definition + rules, or nil if unknown/OFF/inactive.
    public func lookup(_ code: String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? {
        // Prefer the live configuration service (reflects user edits).
        if let service = configurationService {
            return service.lookup(code)
        }

        // Fallback: seeded defaults.
        let normalized = code.uppercased()
        guard normalized != "OFF", let def = seededByCode[normalized] else {
            return nil
        }
        let rules = (normalized == "C5") ? seededC5Rules : []
        return (def, rules)
    }

    /// A closure form of the lookup, for injection into services.
    public var lookupClosure: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? {
        { self.lookup($0) }
    }
}
