// ShiftFlow — Domain Layer
// Services/ShiftSeedProvider.swift
//
// TASK-SHIFT-001: Default C1–C5 seed definitions.
//
// Provides the initial five shift definitions and the C5 special schedule rule.
// The seed operation is idempotent: if definitions already exist, no duplicates are created.
//
// After seeding, the user may edit these from Settings.
// The seed values are initial defaults only.

import Foundation

/// Provides default shift definitions for first-launch seeding.
public enum ShiftSeedProvider {

    // MARK: - Stable UUIDs for seed definitions

    /// Stable IDs ensure idempotent seeding (same ID = same definition).
    public static let c1ID = UUID(uuidString: "00000001-0001-0001-0001-000000000001")!
    public static let c2ID = UUID(uuidString: "00000002-0002-0002-0002-000000000002")!
    public static let c3ID = UUID(uuidString: "00000003-0003-0003-0003-000000000003")!
    public static let c4ID = UUID(uuidString: "00000004-0004-0004-0004-000000000004")!
    public static let c5ID = UUID(uuidString: "00000005-0005-0005-0005-000000000005")!
    public static let c5SpecialRuleID = UUID(uuidString: "00000005-0005-0005-0005-000000000050")!

    // MARK: - Default Shift Definitions

    /// C1: 07:00–16:30, Break 11:00–12:00
    public static func makeC1(createdAt: Date = Date()) -> ShiftDefinition {
        ShiftDefinition(
            id: c1ID,
            code: "C1",
            name: "C1",
            startHour: 7, startMinute: 0,
            endHour: 16, endMinute: 30,
            breakStartHour: 11, breakStartMinute: 0,
            breakEndHour: 12, breakEndMinute: 0,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    /// C2: 07:30–17:00, Break 11:30–12:30
    public static func makeC2(createdAt: Date = Date()) -> ShiftDefinition {
        ShiftDefinition(
            id: c2ID,
            code: "C2",
            name: "C2",
            startHour: 7, startMinute: 30,
            endHour: 17, endMinute: 0,
            breakStartHour: 11, breakStartMinute: 30,
            breakEndHour: 12, breakEndMinute: 30,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    /// C3: 08:00–17:30, Break 12:00–13:00
    public static func makeC3(createdAt: Date = Date()) -> ShiftDefinition {
        ShiftDefinition(
            id: c3ID,
            code: "C3",
            name: "C3",
            startHour: 8, startMinute: 0,
            endHour: 17, endMinute: 30,
            breakStartHour: 12, breakStartMinute: 0,
            breakEndHour: 13, breakEndMinute: 0,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    /// C4: 08:30–18:00, Break 12:30–13:30
    public static func makeC4(createdAt: Date = Date()) -> ShiftDefinition {
        ShiftDefinition(
            id: c4ID,
            code: "C4",
            name: "C4",
            startHour: 8, startMinute: 30,
            endHour: 18, endMinute: 0,
            breakStartHour: 12, breakStartMinute: 30,
            breakEndHour: 13, breakEndMinute: 30,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    /// C5 Normal: 11:30–21:00, Break 16:30–17:30
    /// (Special schedule for days 10–20 is defined as a ScheduleRule.)
    public static func makeC5(createdAt: Date = Date()) -> ShiftDefinition {
        ShiftDefinition(
            id: c5ID,
            code: "C5",
            name: "C5",
            startHour: 11, startMinute: 30,
            endHour: 21, endMinute: 0,
            breakStartHour: 16, breakStartMinute: 30,
            breakEndHour: 17, breakEndMinute: 30,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    // MARK: - Default Schedule Rules

    /// C5 Special Schedule: Day 10–20 inclusive → 12:00–21:30, Break 16:30–17:30
    public static func makeC5SpecialRule() -> ScheduleRule {
        ScheduleRule(
            id: c5SpecialRuleID,
            shiftID: c5ID,
            startDayOfMonth: 10,
            endDayOfMonth: 20,
            startHour: 12, startMinute: 0,
            endHour: 21, endMinute: 30,
            breakStartHour: 16, breakStartMinute: 30,
            breakEndHour: 17, breakEndMinute: 30,
            priority: 1,
            isActive: true
        )
    }

    // MARK: - Seed Collections

    /// All default shift definitions.
    public static func allDefaultShifts(createdAt: Date = Date()) -> [ShiftDefinition] {
        [
            makeC1(createdAt: createdAt),
            makeC2(createdAt: createdAt),
            makeC3(createdAt: createdAt),
            makeC4(createdAt: createdAt),
            makeC5(createdAt: createdAt)
        ]
    }

    /// All default schedule rules.
    public static func allDefaultRules() -> [ScheduleRule] {
        [makeC5SpecialRule()]
    }

    // MARK: - Idempotent Seed

    /// Returns the shift definitions that should be seeded, excluding any
    /// whose IDs already exist in the provided `existingIDs` set.
    ///
    /// This ensures idempotent seeding: calling seed multiple times
    /// does not create duplicate definitions.
    ///
    /// - Parameter existingIDs: Set of UUIDs already present in persistence.
    /// - Returns: Only the shift definitions that do not already exist.
    public static func shiftsToSeed(existingIDs: Set<UUID>, createdAt: Date = Date()) -> [ShiftDefinition] {
        allDefaultShifts(createdAt: createdAt).filter { !existingIDs.contains($0.id) }
    }

    /// Returns the schedule rules that should be seeded, excluding any
    /// whose IDs already exist in the provided `existingIDs` set.
    ///
    /// - Parameter existingIDs: Set of UUIDs already present in persistence.
    /// - Returns: Only the schedule rules that do not already exist.
    public static func rulesToSeed(existingIDs: Set<UUID>) -> [ScheduleRule] {
        allDefaultRules().filter { !existingIDs.contains($0.id) }
    }
}
