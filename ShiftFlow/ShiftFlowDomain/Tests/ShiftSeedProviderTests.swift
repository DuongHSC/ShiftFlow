// ShiftFlow — Domain Tests
// ShiftSeedProviderTests.swift
//
// TASK-SHIFT-001: Seed provider unit tests.
//
// Tests cover:
// - All five shift definitions exist (C1–C5)
// - Correct default values for each shift
// - C5 special rule exists with correct boundaries
// - Idempotent seed: running twice does not create duplicates
// - Partial seed: only missing definitions are returned

import XCTest
@testable import ShiftFlowDomain

final class ShiftSeedProviderTests: XCTestCase {

    // MARK: - Default Shift Existence

    func testAllDefaultShiftsContainsFiveDefinitions() {
        let shifts = ShiftSeedProvider.allDefaultShifts()
        XCTAssertEqual(shifts.count, 5)
    }

    func testC1ExistsInDefaults() {
        let shifts = ShiftSeedProvider.allDefaultShifts()
        let c1 = shifts.first { $0.code == "C1" }
        XCTAssertNotNil(c1, "C1 must exist in default shifts")
    }

    func testC2ExistsInDefaults() {
        let shifts = ShiftSeedProvider.allDefaultShifts()
        let c2 = shifts.first { $0.code == "C2" }
        XCTAssertNotNil(c2, "C2 must exist in default shifts")
    }

    func testC3ExistsInDefaults() {
        let shifts = ShiftSeedProvider.allDefaultShifts()
        let c3 = shifts.first { $0.code == "C3" }
        XCTAssertNotNil(c3, "C3 must exist in default shifts")
    }

    func testC4ExistsInDefaults() {
        let shifts = ShiftSeedProvider.allDefaultShifts()
        let c4 = shifts.first { $0.code == "C4" }
        XCTAssertNotNil(c4, "C4 must exist in default shifts")
    }

    func testC5ExistsInDefaults() {
        let shifts = ShiftSeedProvider.allDefaultShifts()
        let c5 = shifts.first { $0.code == "C5" }
        XCTAssertNotNil(c5, "C5 must exist in default shifts")
    }

    // MARK: - Default Values Verification

    func testC1DefaultValues() {
        let c1 = ShiftSeedProvider.makeC1()
        XCTAssertEqual(c1.code, "C1")
        XCTAssertEqual(c1.startHour, 7)
        XCTAssertEqual(c1.startMinute, 0)
        XCTAssertEqual(c1.endHour, 16)
        XCTAssertEqual(c1.endMinute, 30)
        XCTAssertEqual(c1.breakStartHour, 11)
        XCTAssertEqual(c1.breakStartMinute, 0)
        XCTAssertEqual(c1.breakEndHour, 12)
        XCTAssertEqual(c1.breakEndMinute, 0)
        XCTAssertTrue(c1.isActive)
    }

    func testC2DefaultValues() {
        let c2 = ShiftSeedProvider.makeC2()
        XCTAssertEqual(c2.code, "C2")
        XCTAssertEqual(c2.startHour, 7)
        XCTAssertEqual(c2.startMinute, 30)
        XCTAssertEqual(c2.endHour, 17)
        XCTAssertEqual(c2.endMinute, 0)
        XCTAssertEqual(c2.breakStartHour, 11)
        XCTAssertEqual(c2.breakStartMinute, 30)
        XCTAssertEqual(c2.breakEndHour, 12)
        XCTAssertEqual(c2.breakEndMinute, 30)
        XCTAssertTrue(c2.isActive)
    }

    func testC3DefaultValues() {
        let c3 = ShiftSeedProvider.makeC3()
        XCTAssertEqual(c3.code, "C3")
        XCTAssertEqual(c3.startHour, 8)
        XCTAssertEqual(c3.startMinute, 0)
        XCTAssertEqual(c3.endHour, 17)
        XCTAssertEqual(c3.endMinute, 30)
        XCTAssertEqual(c3.breakStartHour, 12)
        XCTAssertEqual(c3.breakStartMinute, 0)
        XCTAssertEqual(c3.breakEndHour, 13)
        XCTAssertEqual(c3.breakEndMinute, 0)
        XCTAssertTrue(c3.isActive)
    }

    func testC4DefaultValues() {
        let c4 = ShiftSeedProvider.makeC4()
        XCTAssertEqual(c4.code, "C4")
        XCTAssertEqual(c4.startHour, 8)
        XCTAssertEqual(c4.startMinute, 30)
        XCTAssertEqual(c4.endHour, 18)
        XCTAssertEqual(c4.endMinute, 0)
        XCTAssertEqual(c4.breakStartHour, 12)
        XCTAssertEqual(c4.breakStartMinute, 30)
        XCTAssertEqual(c4.breakEndHour, 13)
        XCTAssertEqual(c4.breakEndMinute, 30)
        XCTAssertTrue(c4.isActive)
    }

    func testC5DefaultValues() {
        let c5 = ShiftSeedProvider.makeC5()
        XCTAssertEqual(c5.code, "C5")
        XCTAssertEqual(c5.startHour, 11)
        XCTAssertEqual(c5.startMinute, 30)
        XCTAssertEqual(c5.endHour, 21)
        XCTAssertEqual(c5.endMinute, 0)
        XCTAssertEqual(c5.breakStartHour, 16)
        XCTAssertEqual(c5.breakStartMinute, 30)
        XCTAssertEqual(c5.breakEndHour, 17)
        XCTAssertEqual(c5.breakEndMinute, 30)
        XCTAssertTrue(c5.isActive)
    }

    // MARK: - C5 Special Rule

    func testC5SpecialRuleExists() {
        let rules = ShiftSeedProvider.allDefaultRules()
        XCTAssertEqual(rules.count, 1)
    }

    func testC5SpecialRuleValues() {
        let rule = ShiftSeedProvider.makeC5SpecialRule()
        XCTAssertEqual(rule.shiftID, ShiftSeedProvider.c5ID)
        XCTAssertEqual(rule.startDayOfMonth, 10)
        XCTAssertEqual(rule.endDayOfMonth, 20)
        XCTAssertEqual(rule.startHour, 12)
        XCTAssertEqual(rule.startMinute, 0)
        XCTAssertEqual(rule.endHour, 21)
        XCTAssertEqual(rule.endMinute, 30)
        XCTAssertEqual(rule.breakStartHour, 16)
        XCTAssertEqual(rule.breakStartMinute, 30)
        XCTAssertEqual(rule.breakEndHour, 17)
        XCTAssertEqual(rule.breakEndMinute, 30)
        XCTAssertTrue(rule.isActive)
    }

    func testC5SpecialRuleBoundaryDay9DoesNotApply() {
        let rule = ShiftSeedProvider.makeC5SpecialRule()
        XCTAssertFalse(rule.applies(toDayOfMonth: 9), "Day 9 must NOT match special rule")
    }

    func testC5SpecialRuleBoundaryDay10Applies() {
        let rule = ShiftSeedProvider.makeC5SpecialRule()
        XCTAssertTrue(rule.applies(toDayOfMonth: 10), "Day 10 must match special rule")
    }

    func testC5SpecialRuleBoundaryDay20Applies() {
        let rule = ShiftSeedProvider.makeC5SpecialRule()
        XCTAssertTrue(rule.applies(toDayOfMonth: 20), "Day 20 must match special rule")
    }

    func testC5SpecialRuleBoundaryDay21DoesNotApply() {
        let rule = ShiftSeedProvider.makeC5SpecialRule()
        XCTAssertFalse(rule.applies(toDayOfMonth: 21), "Day 21 must NOT match special rule")
    }

    // MARK: - Idempotent Seed Tests

    func testSeedWithNoExistingIDsReturnsAllFive() {
        let toSeed = ShiftSeedProvider.shiftsToSeed(existingIDs: Set())
        XCTAssertEqual(toSeed.count, 5, "First seed must return all 5 definitions")
    }

    func testSeedWithAllExistingIDsReturnsEmpty() {
        let allIDs: Set<UUID> = [
            ShiftSeedProvider.c1ID,
            ShiftSeedProvider.c2ID,
            ShiftSeedProvider.c3ID,
            ShiftSeedProvider.c4ID,
            ShiftSeedProvider.c5ID
        ]
        let toSeed = ShiftSeedProvider.shiftsToSeed(existingIDs: allIDs)
        XCTAssertEqual(toSeed.count, 0, "Second seed must return 0 (no duplicates)")
    }

    func testSeedIsIdempotent() {
        // Simulate: first seed returns 5, second seed returns 0
        let firstSeed = ShiftSeedProvider.shiftsToSeed(existingIDs: Set())
        XCTAssertEqual(firstSeed.count, 5)

        let existingAfterFirst = Set(firstSeed.map { $0.id })
        let secondSeed = ShiftSeedProvider.shiftsToSeed(existingIDs: existingAfterFirst)
        XCTAssertEqual(secondSeed.count, 0, "Running seed twice must not create duplicates")
    }

    func testPartialSeedReturnsOnlyMissing() {
        // Simulate: C1 and C2 already exist
        let existing: Set<UUID> = [ShiftSeedProvider.c1ID, ShiftSeedProvider.c2ID]
        let toSeed = ShiftSeedProvider.shiftsToSeed(existingIDs: existing)

        XCTAssertEqual(toSeed.count, 3, "Partial seed should return 3 missing definitions")

        let codes = Set(toSeed.map { $0.code })
        XCTAssertTrue(codes.contains("C3"))
        XCTAssertTrue(codes.contains("C4"))
        XCTAssertTrue(codes.contains("C5"))
        XCTAssertFalse(codes.contains("C1"))
        XCTAssertFalse(codes.contains("C2"))
    }

    func testRuleSeedWithNoExistingReturnsOne() {
        let toSeed = ShiftSeedProvider.rulesToSeed(existingIDs: Set())
        XCTAssertEqual(toSeed.count, 1)
    }

    func testRuleSeedWithExistingReturnsEmpty() {
        let existing: Set<UUID> = [ShiftSeedProvider.c5SpecialRuleID]
        let toSeed = ShiftSeedProvider.rulesToSeed(existingIDs: existing)
        XCTAssertEqual(toSeed.count, 0, "Rule seed must be idempotent")
    }

    // MARK: - Stable IDs

    func testSeedIDsAreStable() {
        // Call twice and verify same IDs
        let shifts1 = ShiftSeedProvider.allDefaultShifts()
        let shifts2 = ShiftSeedProvider.allDefaultShifts()

        for (s1, s2) in zip(shifts1, shifts2) {
            XCTAssertEqual(s1.id, s2.id, "Seed IDs must be stable across invocations")
        }
    }

    func testAllShiftIDsAreUnique() {
        let shifts = ShiftSeedProvider.allDefaultShifts()
        let ids = Set(shifts.map { $0.id })
        XCTAssertEqual(ids.count, 5, "All shift IDs must be unique")
    }
}
