// ShiftFlow — Domain Tests
// ShiftResolverTests.swift
//
// TASK-SHIFT-001: Comprehensive ShiftResolver unit tests.
//
// Tests cover:
// - C1 resolution
// - C2 resolution
// - C3 resolution
// - C4 resolution
// - C5 normal resolution
// - C5 special (day 10–20) resolution
// - C5 boundary: day 9 (normal), day 10 (special), day 20 (special), day 21 (normal)
// - February (leap year and non-leap year)
// - Year boundary (December/January)
// - Determinism (same input → same output)
// - Seed idempotency

import XCTest
@testable import ShiftFlowDomain

final class ShiftResolverTests: XCTestCase {

    // MARK: - Test Infrastructure

    /// Fixed calendar for deterministic tests.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }

    /// Helper to create a date for a given year/month/day.
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }

    /// Helper to extract hour:minute from a Date.
    private func timeComponents(from date: Date) -> (hour: Int, minute: Int) {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return (hour, minute)
    }

    // MARK: - Seed Data

    private var c1: ShiftDefinition { ShiftSeedProvider.makeC1() }
    private var c2: ShiftDefinition { ShiftSeedProvider.makeC2() }
    private var c3: ShiftDefinition { ShiftSeedProvider.makeC3() }
    private var c4: ShiftDefinition { ShiftSeedProvider.makeC4() }
    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    // MARK: - C1 Tests

    func testC1ResolvesTo0700_1630_Break1100_1200() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c1, rules: [], calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)
        let breakStart = timeComponents(from: resolved.breakStartDateTime)
        let breakEnd = timeComponents(from: resolved.breakEndDateTime)

        XCTAssertEqual(start.hour, 7)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 16)
        XCTAssertEqual(end.minute, 30)
        XCTAssertEqual(breakStart.hour, 11)
        XCTAssertEqual(breakStart.minute, 0)
        XCTAssertEqual(breakEnd.hour, 12)
        XCTAssertEqual(breakEnd.minute, 0)
        XCTAssertEqual(resolved.shiftCode, "C1")
    }

    // MARK: - C2 Tests

    func testC2ResolvesTo0730_1700_Break1130_1230() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c2, rules: [], calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)
        let breakStart = timeComponents(from: resolved.breakStartDateTime)
        let breakEnd = timeComponents(from: resolved.breakEndDateTime)

        XCTAssertEqual(start.hour, 7)
        XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 17)
        XCTAssertEqual(end.minute, 0)
        XCTAssertEqual(breakStart.hour, 11)
        XCTAssertEqual(breakStart.minute, 30)
        XCTAssertEqual(breakEnd.hour, 12)
        XCTAssertEqual(breakEnd.minute, 30)
        XCTAssertEqual(resolved.shiftCode, "C2")
    }

    // MARK: - C3 Tests

    func testC3ResolvesTo0800_1730_Break1200_1300() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c3, rules: [], calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)
        let breakStart = timeComponents(from: resolved.breakStartDateTime)
        let breakEnd = timeComponents(from: resolved.breakEndDateTime)

        XCTAssertEqual(start.hour, 8)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 17)
        XCTAssertEqual(end.minute, 30)
        XCTAssertEqual(breakStart.hour, 12)
        XCTAssertEqual(breakStart.minute, 0)
        XCTAssertEqual(breakEnd.hour, 13)
        XCTAssertEqual(breakEnd.minute, 0)
        XCTAssertEqual(resolved.shiftCode, "C3")
    }

    // MARK: - C4 Tests

    func testC4ResolvesTo0830_1800_Break1230_1330() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c4, rules: [], calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)
        let breakStart = timeComponents(from: resolved.breakStartDateTime)
        let breakEnd = timeComponents(from: resolved.breakEndDateTime)

        XCTAssertEqual(start.hour, 8)
        XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 18)
        XCTAssertEqual(end.minute, 0)
        XCTAssertEqual(breakStart.hour, 12)
        XCTAssertEqual(breakStart.minute, 30)
        XCTAssertEqual(breakEnd.hour, 13)
        XCTAssertEqual(breakEnd.minute, 30)
        XCTAssertEqual(resolved.shiftCode, "C4")
    }

    // MARK: - C5 Normal Tests

    func testC5NormalResolvesTo1130_2100_Break1630_1730() {
        // Day 5 — outside special range
        let date = makeDate(year: 2026, month: 8, day: 5)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)
        let breakStart = timeComponents(from: resolved.breakStartDateTime)
        let breakEnd = timeComponents(from: resolved.breakEndDateTime)

        XCTAssertEqual(start.hour, 11)
        XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 0)
        XCTAssertEqual(breakStart.hour, 16)
        XCTAssertEqual(breakStart.minute, 30)
        XCTAssertEqual(breakEnd.hour, 17)
        XCTAssertEqual(breakEnd.minute, 30)
        XCTAssertEqual(resolved.shiftCode, "C5")
    }

    func testC5NormalOnDay1() {
        let date = makeDate(year: 2026, month: 8, day: 1)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 11)
        XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 0)
    }

    func testC5NormalOnDay25() {
        let date = makeDate(year: 2026, month: 8, day: 25)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 11)
        XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 0)
    }

    // MARK: - C5 Special (Day 10–20) Tests

    func testC5SpecialOnDay15ResolvesTo1200_2130() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)
        let breakStart = timeComponents(from: resolved.breakStartDateTime)
        let breakEnd = timeComponents(from: resolved.breakEndDateTime)

        XCTAssertEqual(start.hour, 12)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
        XCTAssertEqual(breakStart.hour, 16)
        XCTAssertEqual(breakStart.minute, 30)
        XCTAssertEqual(breakEnd.hour, 17)
        XCTAssertEqual(breakEnd.minute, 30)
    }

    // MARK: - C5 Boundary Tests (CRITICAL)

    func testC5UsesNormalScheduleOnDay9() {
        let date = makeDate(year: 2026, month: 8, day: 9)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 11, "Day 9 must use normal schedule start")
        XCTAssertEqual(start.minute, 30, "Day 9 must use normal schedule start")
        XCTAssertEqual(end.hour, 21, "Day 9 must use normal schedule end")
        XCTAssertEqual(end.minute, 0, "Day 9 must use normal schedule end")
    }

    func testC5UsesSpecialScheduleOnDay10() {
        let date = makeDate(year: 2026, month: 8, day: 10)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 12, "Day 10 must use special schedule start")
        XCTAssertEqual(start.minute, 0, "Day 10 must use special schedule start")
        XCTAssertEqual(end.hour, 21, "Day 10 must use special schedule end")
        XCTAssertEqual(end.minute, 30, "Day 10 must use special schedule end")
    }

    func testC5UsesSpecialScheduleOnDay20() {
        let date = makeDate(year: 2026, month: 8, day: 20)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 12, "Day 20 must use special schedule start")
        XCTAssertEqual(start.minute, 0, "Day 20 must use special schedule start")
        XCTAssertEqual(end.hour, 21, "Day 20 must use special schedule end")
        XCTAssertEqual(end.minute, 30, "Day 20 must use special schedule end")
    }

    func testC5UsesNormalScheduleOnDay21() {
        let date = makeDate(year: 2026, month: 8, day: 21)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 11, "Day 21 must use normal schedule start")
        XCTAssertEqual(start.minute, 30, "Day 21 must use normal schedule start")
        XCTAssertEqual(end.hour, 21, "Day 21 must use normal schedule end")
        XCTAssertEqual(end.minute, 0, "Day 21 must use normal schedule end")
    }

    // MARK: - February Tests

    func testC5SpecialOnFebruary10NonLeapYear() {
        // 2025 is not a leap year
        let date = makeDate(year: 2025, month: 2, day: 10)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 12, "Feb 10 (non-leap) must use special")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testC5SpecialOnFebruary20NonLeapYear() {
        // 2025 is not a leap year
        let date = makeDate(year: 2025, month: 2, day: 20)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 12, "Feb 20 (non-leap) must use special")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testC5NormalOnFebruary9NonLeapYear() {
        let date = makeDate(year: 2025, month: 2, day: 9)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)

        XCTAssertEqual(start.hour, 11, "Feb 9 must use normal")
        XCTAssertEqual(start.minute, 30)
    }

    func testC5NormalOnFebruary21NonLeapYear() {
        let date = makeDate(year: 2025, month: 2, day: 21)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)

        XCTAssertEqual(start.hour, 11, "Feb 21 must use normal")
        XCTAssertEqual(start.minute, 30)
    }

    func testC5NormalOnFebruary28NonLeapYear() {
        // Feb 28 is the last day in a non-leap year — day > 20, so normal
        let date = makeDate(year: 2025, month: 2, day: 28)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)

        XCTAssertEqual(start.hour, 11, "Feb 28 (non-leap) must use normal")
        XCTAssertEqual(start.minute, 30)
    }

    func testC5SpecialOnFebruary15LeapYear() {
        // 2024 is a leap year
        let date = makeDate(year: 2024, month: 2, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 12, "Feb 15 (leap) must use special")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testC5NormalOnFebruary29LeapYear() {
        // Feb 29 exists in leap year — day > 20, so normal
        let date = makeDate(year: 2024, month: 2, day: 29)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)

        XCTAssertEqual(start.hour, 11, "Feb 29 (leap) must use normal")
        XCTAssertEqual(start.minute, 30)
    }

    // MARK: - Year Boundary Tests

    func testC5SpecialOnDecember20() {
        let date = makeDate(year: 2026, month: 12, day: 20)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 12, "Dec 20 must use special")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testC5NormalOnDecember21() {
        let date = makeDate(year: 2026, month: 12, day: 21)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 11, "Dec 21 must use normal")
        XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 0)
    }

    func testC5NormalOnDecember31() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)

        XCTAssertEqual(start.hour, 11, "Dec 31 must use normal (day > 20)")
        XCTAssertEqual(start.minute, 30)
    }

    func testC5SpecialOnJanuary10() {
        let date = makeDate(year: 2027, month: 1, day: 10)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 12, "Jan 10 must use special")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testC5SpecialOnJanuary20() {
        let date = makeDate(year: 2027, month: 1, day: 20)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 12, "Jan 20 must use special")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testC5NormalOnJanuary21() {
        let date = makeDate(year: 2027, month: 1, day: 21)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)
        let end = timeComponents(from: resolved.endDateTime)

        XCTAssertEqual(start.hour, 11, "Jan 21 must use normal")
        XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 0)
    }

    func testC5NormalOnJanuary1() {
        let date = makeDate(year: 2027, month: 1, day: 1)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)

        XCTAssertEqual(start.hour, 11, "Jan 1 must use normal (day < 10)")
        XCTAssertEqual(start.minute, 30)
    }

    // MARK: - Determinism Tests

    func testResolverIsDeterministic() {
        let date = makeDate(year: 2026, month: 8, day: 15)

        let resolved1 = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)
        let resolved2 = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        XCTAssertEqual(resolved1, resolved2, "Same input must produce the same output")
    }

    func testResolverIsDeterministicForC1() {
        let date = makeDate(year: 2026, month: 3, day: 7)

        let resolved1 = ShiftResolver.resolve(date: date, shift: c1, rules: [], calendar: calendar)
        let resolved2 = ShiftResolver.resolve(date: date, shift: c1, rules: [], calendar: calendar)

        XCTAssertEqual(resolved1, resolved2)
    }

    func testResolverIsDeterministicAcrossMultipleInvocations() {
        let date = makeDate(year: 2026, month: 6, day: 10)

        var results: [ResolvedShift] = []
        for _ in 0..<10 {
            results.append(ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar))
        }

        let first = results[0]
        for result in results {
            XCTAssertEqual(result, first, "All invocations must produce identical results")
        }
    }

    // MARK: - Inactive Rule Tests

    func testInactiveRuleIsNotApplied() {
        let inactiveRule = ScheduleRule(
            shiftID: c5.id,
            startDayOfMonth: 10,
            endDayOfMonth: 20,
            startHour: 12, startMinute: 0,
            endHour: 21, endMinute: 30,
            breakStartHour: 16, breakStartMinute: 30,
            breakEndHour: 17, breakEndMinute: 30,
            priority: 1,
            isActive: false  // inactive
        )

        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: [inactiveRule], calendar: calendar)

        let start = timeComponents(from: resolved.startDateTime)

        // Should use normal because rule is inactive
        XCTAssertEqual(start.hour, 11, "Inactive rule must not apply")
        XCTAssertEqual(start.minute, 30)
    }

    // MARK: - Priority Tests

    func testHigherPriorityRuleWins() {
        let lowPriority = ScheduleRule(
            shiftID: c5.id,
            startDayOfMonth: 10,
            endDayOfMonth: 20,
            startHour: 12, startMinute: 0,
            endHour: 21, endMinute: 30,
            breakStartHour: 16, breakStartMinute: 30,
            breakEndHour: 17, breakEndMinute: 30,
            priority: 1,
            isActive: true
        )

        let highPriority = ScheduleRule(
            shiftID: c5.id,
            startDayOfMonth: 15,
            endDayOfMonth: 15,
            startHour: 13, startMinute: 0,
            endHour: 22, endMinute: 0,
            breakStartHour: 17, breakStartMinute: 0,
            breakEndHour: 18, breakEndMinute: 0,
            priority: 10,
            isActive: true
        )

        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(
            date: date, shift: c5, rules: [lowPriority, highPriority], calendar: calendar
        )

        let start = timeComponents(from: resolved.startDateTime)

        XCTAssertEqual(start.hour, 13, "Higher priority rule must win")
        XCTAssertEqual(start.minute, 0)
    }

    // MARK: - ShiftID Tracking

    func testResolvedShiftContainsCorrectShiftID() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        XCTAssertEqual(resolved.shiftID, c5.id)
        XCTAssertEqual(resolved.shiftCode, "C5")
    }

    func testResolvedShiftContainsCorrectDate() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let dayComponent = calendar.component(.day, from: resolved.date)
        let monthComponent = calendar.component(.month, from: resolved.date)
        let yearComponent = calendar.component(.year, from: resolved.date)

        XCTAssertEqual(dayComponent, 15)
        XCTAssertEqual(monthComponent, 8)
        XCTAssertEqual(yearComponent, 2026)
    }
}
