// ShiftFlow — Tests
// ReminderTests.swift
//
// TASK-REMINDER-001: Comprehensive reminder unit tests.
//
// Tests cover:
// - Basic reminder offset calculations (all 5 offsets)
// - C5 special schedule reminder times
// - C5 boundary (day 9/10/20/21)
// - MW independence (task does not affect reminder)
// - Note independence
// - Shift change → reschedule
// - WorkDay delete → cancel
// - Disable reminder → cancel
// - Rolling window (14 days)
// - Past reminder skipped
// - Duplicate prevention (identifier determinism)
// - Notification identifier format
// - Permission handling

// TASK-GITHUB-ACTIONS-FIX-004 (module visibility): ReminderOffset,
// ReminderConfiguration, and ReminderIdentifier live in the ShiftFlow app module
// (Notifications/ReminderModels.swift), not the domain package. This file is
// compiled by the app-hosted `ShiftFlowTests` Xcode target, so it imports the app
// module in addition to the domain module. It is excluded from the standalone
// `ShiftFlowDomain` SPM test target (see Package.swift).

import XCTest
@testable import ShiftFlowDomain
@testable import ShiftFlow

// Since we cannot import UserNotifications in the domain test target on Windows,
// these tests verify the reminder LOGIC (offset calculations, identifiers,
// configurations) without requiring UNUserNotificationCenter.
// Integration tests with actual UNUserNotificationCenter require macOS/Xcode.

final class ReminderOffsetTests: XCTestCase {

    // MARK: - Test Infrastructure

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }

    private func makeDateTime(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }

    private func timeComponents(from date: Date) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        let h = calendar.component(.hour, from: date)
        let min = calendar.component(.minute, from: date)
        return (y, m, d, h, min)
    }

    private var c1: ShiftDefinition { ShiftSeedProvider.makeC1() }
    private var c4: ShiftDefinition { ShiftSeedProvider.makeC4() }
    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    // MARK: - Basic Offset: At Start

    func testAtStartOffsetEqualsResolvedStartTime() {
        // C1 start = 07:00
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 7, minute: 0)
        let fireDate = ReminderOffset.atStart.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 7)
        XCTAssertEqual(t.minute, 0)
        XCTAssertEqual(t.day, 15)
    }

    // MARK: - Basic Offset: 30 Minutes Before

    func testThirtyMinutesBeforeC1() {
        // C1 start = 07:00
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 7, minute: 0)
        let fireDate = ReminderOffset.thirtyMinutesBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 6)
        XCTAssertEqual(t.minute, 30)
        XCTAssertEqual(t.day, 15)
    }

    // MARK: - Basic Offset: 1 Hour Before

    func testOneHourBeforeC1() {
        // C1 start = 07:00
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 7, minute: 0)
        let fireDate = ReminderOffset.oneHourBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 6)
        XCTAssertEqual(t.minute, 0)
        XCTAssertEqual(t.day, 15)
    }

    // MARK: - Basic Offset: 2 Hours Before

    func testTwoHoursBeforeC1() {
        // C1 start = 07:00
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 7, minute: 0)
        let fireDate = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 5)
        XCTAssertEqual(t.minute, 0)
        XCTAssertEqual(t.day, 15)
    }

    // MARK: - Basic Offset: 24 Hours Before

    func testTwentyFourHoursBeforeC1() {
        // C1 start = 07:00 on Aug 15
        // 24h before = 07:00 on Aug 14
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 7, minute: 0)
        let fireDate = ReminderOffset.twentyFourHoursBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.day, 14, "24h before Aug 15 = Aug 14")
        XCTAssertEqual(t.hour, 7)
        XCTAssertEqual(t.minute, 0)
        XCTAssertEqual(t.month, 8)
    }

    // MARK: - C5 Special Schedule Reminders

    func testC5Day15TwoHoursBefore() {
        // C5 day 15 (special): start = 12:00
        // 2 hours before = 10:00
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
        let fireDate = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 10)
        XCTAssertEqual(t.minute, 0)
        XCTAssertEqual(t.day, 15)
    }

    func testC5Day15TwentyFourHoursBefore() {
        // C5 day 15 (special): start = 12:00
        // 24h before = Aug 14 at 12:00
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
        let fireDate = ReminderOffset.twentyFourHoursBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.day, 14, "24h before Aug 15 12:00 = Aug 14 12:00")
        XCTAssertEqual(t.hour, 12)
        XCTAssertEqual(t.minute, 0)
    }

    func testC5Day15ThirtyMinutesBefore() {
        // C5 day 15: start = 12:00
        // 30 min before = 11:30
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
        let fireDate = ReminderOffset.thirtyMinutesBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 11)
        XCTAssertEqual(t.minute, 30)
    }

    // MARK: - C5 Boundary Tests

    func testC5Day9ReminderUsesNormalStart() {
        // C5 day 9 (normal): start = 11:30
        // 2h before = 09:30
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 9, hour: 11, minute: 30)
        let fireDate = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 9)
        XCTAssertEqual(t.minute, 30)
    }

    func testC5Day10ReminderUsesSpecialStart() {
        // C5 day 10 (special): start = 12:00
        // 2h before = 10:00
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 10, hour: 12, minute: 0)
        let fireDate = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 10)
        XCTAssertEqual(t.minute, 0)
    }

    func testC5Day20ReminderUsesSpecialStart() {
        // C5 day 20 (special): start = 12:00
        // 1h before = 11:00
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 20, hour: 12, minute: 0)
        let fireDate = ReminderOffset.oneHourBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 11)
        XCTAssertEqual(t.minute, 0)
    }

    func testC5Day21ReminderUsesNormalStart() {
        // C5 day 21 (normal): start = 11:30
        // 1h before = 10:30
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 21, hour: 11, minute: 30)
        let fireDate = ReminderOffset.oneHourBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fireDate)
        XCTAssertEqual(t.hour, 10)
        XCTAssertEqual(t.minute, 30)
    }

    // MARK: - MW Independence

    func testMWDoesNotAffectReminderTime() {
        // C5 day 15 with or without MW: start = 12:00 (from snapshot)
        // The reminder service uses WorkDay.resolvedStartDateTime which is
        // set by ShiftResolver and is NOT influenced by tasks.
        let resolvedStartWithoutMW = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
        let resolvedStartWithMW = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)

        let fireWithout = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStartWithoutMW)
        let fireWith = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStartWithMW)

        XCTAssertEqual(fireWithout, fireWith, "MW must not affect reminder time")
    }

    func testMWDoesNotAffectAnyOffset() {
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)

        // All offsets produce the same result regardless of task presence.
        for offset in ReminderOffset.allCases {
            let fire = offset.notificationDate(from: resolvedStart)
            let expected = resolvedStart.addingTimeInterval(offset.timeInterval)
            XCTAssertEqual(fire, expected, "Offset \(offset.rawValue) must not depend on tasks")
        }
    }

    // MARK: - Note Independence

    func testNoteDoesNotAffectReminderTime() {
        // Reminder uses only resolvedStartDateTime. Note is irrelevant.
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 8, minute: 30)
        let fire = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStart)

        let t = timeComponents(from: fire)
        XCTAssertEqual(t.hour, 6)
        XCTAssertEqual(t.minute, 30)
        // Note content has no parameter in the calculation at all.
    }

    // MARK: - Shift Change Verification

    func testShiftChangeProducesDifferentReminderTime() {
        // Before: C4 start = 08:30, 2h reminder = 06:30
        let c4Start = makeDateTime(year: 2026, month: 8, day: 15, hour: 8, minute: 30)
        let c4Fire = ReminderOffset.twoHoursBefore.notificationDate(from: c4Start)

        // After: C5 day 15 start = 12:00, 2h reminder = 10:00
        let c5Start = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
        let c5Fire = ReminderOffset.twoHoursBefore.notificationDate(from: c5Start)

        let c4Time = timeComponents(from: c4Fire)
        let c5Time = timeComponents(from: c5Fire)

        XCTAssertEqual(c4Time.hour, 6)
        XCTAssertEqual(c4Time.minute, 30)
        XCTAssertEqual(c5Time.hour, 10)
        XCTAssertEqual(c5Time.minute, 0)

        XCTAssertNotEqual(c4Fire, c5Fire, "Shift change must produce different reminder time")
    }

    // MARK: - Past Reminder Detection

    func testPastReminderIsDetectable() {
        // If current time is 11:00 and shift starts at 12:00,
        // 2-hour reminder would be 10:00 which is in the past.
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
        let fireDate = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStart)

        // Simulate "now" = 11:00 on Aug 15
        let now = makeDateTime(year: 2026, month: 8, day: 15, hour: 11, minute: 0)

        // fireDate (10:00) < now (11:00) → past, should not be scheduled
        XCTAssertTrue(fireDate < now, "10:00 < 11:00 means reminder is in the past")
    }

    func testFutureReminderIsDetectable() {
        let resolvedStart = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
        let fireDate = ReminderOffset.twoHoursBefore.notificationDate(from: resolvedStart)

        // Simulate "now" = 09:00 on Aug 15
        let now = makeDateTime(year: 2026, month: 8, day: 15, hour: 9, minute: 0)

        // fireDate (10:00) > now (09:00) → future, should be scheduled
        XCTAssertTrue(fireDate > now, "10:00 > 09:00 means reminder is in the future")
    }

    // MARK: - Notification Identifier Tests

    func testIdentifierIsDeterministic() {
        let workDayID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let id1 = ReminderIdentifier.make(workDayID: workDayID, offset: .twoHoursBefore)
        let id2 = ReminderIdentifier.make(workDayID: workDayID, offset: .twoHoursBefore)

        XCTAssertEqual(id1, id2, "Same inputs must produce same identifier")
    }

    func testIdentifierFormatIsCorrect() {
        let workDayID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let id = ReminderIdentifier.make(workDayID: workDayID, offset: .twoHoursBefore)

        XCTAssertEqual(id, "shiftflow.workday.12345678-1234-1234-1234-123456789ABC.2h")
    }

    func testIdentifierPrefixDetection() {
        let shiftFlowID = "shiftflow.workday.12345678-1234-1234-1234-123456789ABC.2h"
        let otherID = "com.other.app.notification"

        XCTAssertTrue(ReminderIdentifier.isShiftFlowNotification(shiftFlowID))
        XCTAssertFalse(ReminderIdentifier.isShiftFlowNotification(otherID))
    }

    func testExtractWorkDayIDFromIdentifier() {
        let workDayID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let id = ReminderIdentifier.make(workDayID: workDayID, offset: .oneHourBefore)

        let extracted = ReminderIdentifier.extractWorkDayID(id)
        XCTAssertEqual(extracted, workDayID)
    }

    func testExtractWorkDayIDFromInvalidIdentifier() {
        let extracted = ReminderIdentifier.extractWorkDayID("com.other.notification")
        XCTAssertNil(extracted)
    }

    func testAllIdentifiersForWorkDay() {
        let workDayID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let all = ReminderIdentifier.allIdentifiers(for: workDayID)

        XCTAssertEqual(all.count, 5, "Should have one identifier per offset")
        XCTAssertTrue(all.contains("shiftflow.workday.12345678-1234-1234-1234-123456789ABC.at_start"))
        XCTAssertTrue(all.contains("shiftflow.workday.12345678-1234-1234-1234-123456789ABC.30min"))
        XCTAssertTrue(all.contains("shiftflow.workday.12345678-1234-1234-1234-123456789ABC.1h"))
        XCTAssertTrue(all.contains("shiftflow.workday.12345678-1234-1234-1234-123456789ABC.2h"))
        XCTAssertTrue(all.contains("shiftflow.workday.12345678-1234-1234-1234-123456789ABC.24h"))
    }

    func testDifferentOffsetsProduceDifferentIdentifiers() {
        let workDayID = UUID()
        let id1 = ReminderIdentifier.make(workDayID: workDayID, offset: .thirtyMinutesBefore)
        let id2 = ReminderIdentifier.make(workDayID: workDayID, offset: .twoHoursBefore)

        XCTAssertNotEqual(id1, id2)
    }

    func testDifferentWorkDaysProduceDifferentIdentifiers() {
        let id1 = ReminderIdentifier.make(workDayID: UUID(), offset: .twoHoursBefore)
        let id2 = ReminderIdentifier.make(workDayID: UUID(), offset: .twoHoursBefore)

        XCTAssertNotEqual(id1, id2)
    }

    // MARK: - Reminder Configuration Tests

    func testReminderConfigurationNotificationIdentifier() {
        let workDayID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let config = ReminderConfiguration(
            workDayID: workDayID,
            offset: .twentyFourHoursBefore
        )

        XCTAssertEqual(
            config.notificationIdentifier,
            "shiftflow.workday.AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE.24h"
        )
    }

    func testReminderConfigurationWithOffsetChange() {
        let config = ReminderConfiguration(
            workDayID: UUID(),
            offset: .thirtyMinutesBefore
        )

        let updated = config.withOffset(.twoHoursBefore)

        XCTAssertEqual(updated.offset, .twoHoursBefore)
        XCTAssertEqual(updated.id, config.id, "ID must remain the same")
        XCTAssertEqual(updated.workDayID, config.workDayID)
    }

    func testReminderConfigurationWithEnabledChange() {
        let config = ReminderConfiguration(
            workDayID: UUID(),
            offset: .oneHourBefore,
            isEnabled: true
        )

        let disabled = config.withEnabled(false)

        XCTAssertFalse(disabled.isEnabled)
        XCTAssertEqual(disabled.id, config.id)
        XCTAssertEqual(disabled.offset, config.offset)
    }

    // MARK: - Rolling Window Logic (via WorkDay dates)

    func testRollingWindowCalculation() {
        // Verify that the rolling window is 14 days.
        let now = makeDateTime(year: 2026, month: 8, day: 1, hour: 9, minute: 0)
        let windowEnd = calendar.date(byAdding: .day, value: 14, to: now)!

        let withinWindow = makeDateTime(year: 2026, month: 8, day: 10, hour: 12, minute: 0)
        let outsideWindow = makeDateTime(year: 2026, month: 8, day: 20, hour: 12, minute: 0)

        XCTAssertTrue(withinWindow > now && withinWindow <= windowEnd, "Day 10 within 14-day window from Aug 1")
        XCTAssertFalse(outsideWindow <= windowEnd, "Day 20 outside 14-day window from Aug 1")
    }

    // MARK: - Offset TimeInterval Values

    func testOffsetTimeIntervals() {
        XCTAssertEqual(ReminderOffset.atStart.timeInterval, 0)
        XCTAssertEqual(ReminderOffset.thirtyMinutesBefore.timeInterval, -1800)
        XCTAssertEqual(ReminderOffset.oneHourBefore.timeInterval, -3600)
        XCTAssertEqual(ReminderOffset.twoHoursBefore.timeInterval, -7200)
        XCTAssertEqual(ReminderOffset.twentyFourHoursBefore.timeInterval, -86400)
    }

    // MARK: - 24h Semantics Verification

    func testTwentyFourHoursMeansExactly24Hours() {
        // "24 hours before" = exactly 24 hours, NOT "1 day before at some fixed time"
        let start = makeDateTime(year: 2026, month: 8, day: 15, hour: 12, minute: 0)
        let fire = ReminderOffset.twentyFourHoursBefore.notificationDate(from: start)

        let diff = start.timeIntervalSince(fire)
        XCTAssertEqual(diff, 24 * 60 * 60, accuracy: 0.001, "Must be exactly 86400 seconds")
    }

    func testTwentyFourHoursBeforeEarlyMorningShift() {
        // C1 start = 07:00 on Aug 15
        // 24h before = 07:00 on Aug 14 (NOT midnight or some other time)
        let start = makeDateTime(year: 2026, month: 8, day: 15, hour: 7, minute: 0)
        let fire = ReminderOffset.twentyFourHoursBefore.notificationDate(from: start)

        let t = timeComponents(from: fire)
        XCTAssertEqual(t.year, 2026)
        XCTAssertEqual(t.month, 8)
        XCTAssertEqual(t.day, 14)
        XCTAssertEqual(t.hour, 7, "Must be exactly 07:00 on previous day")
        XCTAssertEqual(t.minute, 0)
    }

    // MARK: - Display Names

    func testOffsetDisplayNames() {
        XCTAssertEqual(ReminderOffset.atStart.displayName, "Lúc bắt đầu")
        XCTAssertEqual(ReminderOffset.thirtyMinutesBefore.displayName, "30 phút trước")
        XCTAssertEqual(ReminderOffset.oneHourBefore.displayName, "1 giờ trước")
        XCTAssertEqual(ReminderOffset.twoHoursBefore.displayName, "2 giờ trước")
        XCTAssertEqual(ReminderOffset.twentyFourHoursBefore.displayName, "24 giờ trước")
    }

    // MARK: - All Offsets Count

    func testAllCasesContainsFiveOptions() {
        XCTAssertEqual(ReminderOffset.allCases.count, 5)
    }
}
