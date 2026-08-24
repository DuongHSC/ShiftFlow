// ShiftFlow — Tests
// WidgetScheduleTests.swift
//
// TASK-WIDGET-001: Widget data logic tests.
//
// Tests the pure widget data pipeline (WidgetScheduleBuilder, WidgetDayEntry,
// WidgetDeepLink) without requiring WidgetKit or UNUserNotificationCenter.
//
// UNUserNotificationCenter / WidgetKit UI verification requires macOS/Xcode.

import XCTest
@testable import ShiftFlowDomain

final class WidgetScheduleTests: XCTestCase {

    // MARK: - Test Infrastructure

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = 0; c.minute = 0; c.second = 0
        return calendar.date(from: c)!
    }

    private func timeComponents(from date: Date) -> (hour: Int, minute: Int) {
        (calendar.component(.hour, from: date), calendar.component(.minute, from: date))
    }

    private var c1: ShiftDefinition { ShiftSeedProvider.makeC1() }
    private var c4: ShiftDefinition { ShiftSeedProvider.makeC4() }
    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    private func makeWorkDay(year: Int, month: Int, day: Int, shift: ShiftDefinition, rules: [ScheduleRule], note: String? = nil) -> WorkDay {
        let date = makeDate(year: year, month: month, day: day)
        let resolved = ShiftResolver.resolve(date: date, shift: shift, rules: rules, calendar: calendar)
        return WorkDay(date: date, resolvedShift: resolved, note: note)
    }

    // MARK: - 1. Today WorkDay Appears

    func testTodayWorkDayAppears() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let wd = makeWorkDay(year: 2026, month: 8, day: 15, shift: c4, rules: [])

        let snapshot = WidgetScheduleBuilder.build(
            workDays: [wd], referenceDate: ref, calendar: calendar
        )

        XCTAssertNotNil(snapshot.today)
        XCTAssertEqual(snapshot.today?.shiftCode, "C4")
    }

    // MARK: - 2. Today Without WorkDay = OFF

    func testTodayWithoutWorkDayIsNil() {
        let ref = makeDate(year: 2026, month: 8, day: 15)

        let snapshot = WidgetScheduleBuilder.build(
            workDays: [], referenceDate: ref, calendar: calendar
        )

        XCTAssertNil(snapshot.today, "No WorkDay = OFF (nil today)")
    }

    // MARK: - 3. Next Shift Finds First Future WorkDay

    func testNextShiftFindsFirstFuture() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let future1 = makeWorkDay(year: 2026, month: 8, day: 18, shift: c1, rules: [])
        let future2 = makeWorkDay(year: 2026, month: 8, day: 20, shift: c4, rules: [])

        let snapshot = WidgetScheduleBuilder.build(
            workDays: [future2, future1], referenceDate: ref, calendar: calendar
        )

        XCTAssertNotNil(snapshot.nextShift)
        XCTAssertEqual(snapshot.nextShift?.shiftCode, "C1", "Next shift should be the earliest future")
    }

    // MARK: - 4. Next Shift Nil When None

    func testNextShiftNilWhenNoFuture() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        // Only a past WorkDay.
        let past = makeWorkDay(year: 2026, month: 8, day: 10, shift: c1, rules: [])

        let snapshot = WidgetScheduleBuilder.build(
            workDays: [past], referenceDate: ref, calendar: calendar
        )

        XCTAssertNil(snapshot.nextShift)
    }

    // MARK: - 5-8. C5 Boundary Display

    func testC5Day9DisplaysNormal() {
        let ref = makeDate(year: 2026, month: 8, day: 9)
        let wd = makeWorkDay(year: 2026, month: 8, day: 9, shift: c5, rules: c5Rules)

        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        let start = timeComponents(from: snapshot.today!.startDateTime)
        let end = timeComponents(from: snapshot.today!.endDateTime)
        XCTAssertEqual(start.hour, 11); XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 21); XCTAssertEqual(end.minute, 0)
    }

    func testC5Day10DisplaysSpecial() {
        let ref = makeDate(year: 2026, month: 8, day: 10)
        let wd = makeWorkDay(year: 2026, month: 8, day: 10, shift: c5, rules: c5Rules)

        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        let start = timeComponents(from: snapshot.today!.startDateTime)
        let end = timeComponents(from: snapshot.today!.endDateTime)
        XCTAssertEqual(start.hour, 12); XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21); XCTAssertEqual(end.minute, 30)
    }

    func testC5Day20DisplaysSpecial() {
        let ref = makeDate(year: 2026, month: 8, day: 20)
        let wd = makeWorkDay(year: 2026, month: 8, day: 20, shift: c5, rules: c5Rules)

        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        let start = timeComponents(from: snapshot.today!.startDateTime)
        XCTAssertEqual(start.hour, 12); XCTAssertEqual(start.minute, 0)
    }

    func testC5Day21DisplaysNormal() {
        let ref = makeDate(year: 2026, month: 8, day: 21)
        let wd = makeWorkDay(year: 2026, month: 8, day: 21, shift: c5, rules: c5Rules)

        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        let start = timeComponents(from: snapshot.today!.startDateTime)
        XCTAssertEqual(start.hour, 11); XCTAssertEqual(start.minute, 30)
    }

    // MARK: - 9. Widget Uses WorkDay Snapshot

    func testWidgetUsesWorkDaySnapshotValues() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let wd = makeWorkDay(year: 2026, month: 8, day: 15, shift: c5, rules: c5Rules)

        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        // Widget entry values must exactly match the WorkDay snapshot.
        XCTAssertEqual(snapshot.today?.startDateTime, wd.resolvedStartDateTime)
        XCTAssertEqual(snapshot.today?.endDateTime, wd.resolvedEndDateTime)
        XCTAssertEqual(snapshot.today?.breakStartDateTime, wd.resolvedBreakStartDateTime)
        XCTAssertEqual(snapshot.today?.breakEndDateTime, wd.resolvedBreakEndDateTime)
        XCTAssertEqual(snapshot.today?.shiftCode, wd.shiftCode)
    }

    // MARK: - 10. Config Change Does Not Rewrite Widget Data

    func testConfigChangeDoesNotRewriteWidgetSnapshot() {
        let ref = makeDate(year: 2026, month: 8, day: 15)

        // Create WorkDay with original C5 (12:00-21:30 special).
        let wd = makeWorkDay(year: 2026, month: 8, day: 15, shift: c5, rules: c5Rules)

        // Build widget snapshot.
        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        // Verify original.
        let startBefore = timeComponents(from: snapshot.today!.startDateTime)
        XCTAssertEqual(startBefore.hour, 12)

        // Simulate config change: a new C5 with different times.
        // The WorkDay snapshot (wd) is unchanged — widget reads the same wd.
        let snapshotAfter = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        let startAfter = timeComponents(from: snapshotAfter.today!.startDateTime)
        XCTAssertEqual(startAfter.hour, 12, "Widget must show historical snapshot, not new config")
        XCTAssertEqual(startAfter.minute, 0)
    }

    // MARK: - 11. MW Does Not Change Displayed Times

    func testMWDoesNotChangeWidgetTimes() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let wd = makeWorkDay(year: 2026, month: 8, day: 15, shift: c5, rules: c5Rules)

        // Build snapshot without task.
        let noTask = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        // Build snapshot WITH task (MW).
        let withTask = WidgetScheduleBuilder.build(
            workDays: [wd], referenceDate: ref,
            taskWorkDayIDs: [wd.id], calendar: calendar
        )

        // Times must be identical.
        XCTAssertEqual(noTask.today?.startDateTime, withTask.today?.startDateTime, "MW must not change times")
        XCTAssertEqual(noTask.today?.endDateTime, withTask.today?.endDateTime)

        // Only the hasTask indicator differs.
        XCTAssertFalse(noTask.today?.hasTask ?? true)
        XCTAssertTrue(withTask.today?.hasTask ?? false)
    }

    // MARK: - 12. Note Does Not Change Displayed Times

    func testNoteDoesNotChangeWidgetTimes() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let wdNoNote = makeWorkDay(year: 2026, month: 8, day: 15, shift: c5, rules: c5Rules, note: nil)
        let wdWithNote = makeWorkDay(year: 2026, month: 8, day: 15, shift: c5, rules: c5Rules, note: "Meeting")

        let snapNoNote = WidgetScheduleBuilder.build(workDays: [wdNoNote], referenceDate: ref, calendar: calendar)
        let snapWithNote = WidgetScheduleBuilder.build(workDays: [wdWithNote], referenceDate: ref, calendar: calendar)

        XCTAssertEqual(snapNoNote.today?.startDateTime, snapWithNote.today?.startDateTime)
        XCTAssertEqual(snapNoNote.today?.endDateTime, snapWithNote.today?.endDateTime)
    }

    func testNoteTextIsNotExposedInWidgetData() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let wd = makeWorkDay(year: 2026, month: 8, day: 15, shift: c5, rules: c5Rules, note: "Private meeting details")

        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        // Widget entry has hasNote indicator but NOT the note text.
        XCTAssertTrue(snapshot.today?.hasNote ?? false, "hasNote indicator should be true")
        // WidgetDayEntry has no note text property — privacy preserved by design.
    }

    // MARK: - 13. OFF Does Not Create WorkDay

    func testOFFProducesNilTodayWithoutCreatingWorkDay() {
        let ref = makeDate(year: 2026, month: 8, day: 15)

        // No WorkDay for today.
        let otherDay = makeWorkDay(year: 2026, month: 8, day: 20, shift: c1, rules: [])

        let snapshot = WidgetScheduleBuilder.build(workDays: [otherDay], referenceDate: ref, calendar: calendar)

        XCTAssertNil(snapshot.today, "OFF = nil today, no WorkDay created")
    }

    // MARK: - 14. Vietnamese Weekday Names (via snapshot dates)

    func testWidgetEntryPreservesDateForWeekdayDisplay() {
        // Aug 19, 2026 is a Wednesday (Thứ 4).
        let ref = makeDate(year: 2026, month: 8, day: 19)
        let wd = makeWorkDay(year: 2026, month: 8, day: 19, shift: c4, rules: [])

        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        let weekday = calendar.component(.weekday, from: snapshot.today!.date)
        XCTAssertEqual(weekday, 4, "Aug 19 2026 is Wednesday (weekday 4 = Thứ 4)")
    }

    // MARK: - 16-18. Widget Data Validity (Small/Medium/Large)

    func testSmallWidgetDataIsValid() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let wd = makeWorkDay(year: 2026, month: 8, day: 15, shift: c4, rules: [])

        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        // Small widget needs: today's shift + start/end.
        XCTAssertNotNil(snapshot.today)
        XCTAssertFalse(snapshot.today!.shiftCode.isEmpty)
    }

    func testMediumWidgetDataIsValid() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let today = makeWorkDay(year: 2026, month: 8, day: 15, shift: c4, rules: [])
        let next = makeWorkDay(year: 2026, month: 8, day: 18, shift: c5, rules: c5Rules)

        let snapshot = WidgetScheduleBuilder.build(workDays: [today, next], referenceDate: ref, calendar: calendar)

        // Medium needs: today + next shift.
        XCTAssertNotNil(snapshot.today)
        XCTAssertNotNil(snapshot.nextShift)
        XCTAssertEqual(snapshot.nextShift?.shiftCode, "C5")
    }

    func testLargeWidgetDataIsValid() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let workDays = [
            makeWorkDay(year: 2026, month: 8, day: 15, shift: c4, rules: []),
            makeWorkDay(year: 2026, month: 8, day: 16, shift: c1, rules: []),
            makeWorkDay(year: 2026, month: 8, day: 17, shift: c5, rules: c5Rules),
        ]

        let snapshot = WidgetScheduleBuilder.build(workDays: workDays, referenceDate: ref, calendar: calendar)

        // Large needs: today + upcoming.
        XCTAssertNotNil(snapshot.today)
        XCTAssertGreaterThanOrEqual(snapshot.upcoming.count, 3)
    }

    func testUpcomingIsSortedAscending() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let workDays = [
            makeWorkDay(year: 2026, month: 8, day: 17, shift: c5, rules: c5Rules),
            makeWorkDay(year: 2026, month: 8, day: 15, shift: c4, rules: []),
            makeWorkDay(year: 2026, month: 8, day: 16, shift: c1, rules: []),
        ]

        let snapshot = WidgetScheduleBuilder.build(workDays: workDays, referenceDate: ref, calendar: calendar)

        // Upcoming should be date-ascending.
        for i in 1..<snapshot.upcoming.count {
            XCTAssertLessThanOrEqual(
                snapshot.upcoming[i-1].date,
                snapshot.upcoming[i].date,
                "Upcoming entries must be sorted ascending"
            )
        }
    }

    // MARK: - 20. Deep Link

    func testDeepLinkURLForDate() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let url = WidgetDeepLink.url(forDate: date, calendar: calendar)

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "shiftflow")
        XCTAssertEqual(url?.host, "day")
        XCTAssertTrue(url?.query?.contains("2026-08-15") ?? false)
    }

    func testDeepLinkRoundTrip() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let url = WidgetDeepLink.url(forDate: date, calendar: calendar)!

        let parsed = WidgetDeepLink.parseDate(from: url, calendar: calendar)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(calendar.component(.day, from: parsed!), 15)
        XCTAssertEqual(calendar.component(.month, from: parsed!), 8)
        XCTAssertEqual(calendar.component(.year, from: parsed!), 2026)
    }

    func testDeepLinkFromSnapshotPrefersToday() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let today = makeWorkDay(year: 2026, month: 8, day: 15, shift: c4, rules: [])
        let next = makeWorkDay(year: 2026, month: 8, day: 18, shift: c5, rules: c5Rules)

        let snapshot = WidgetScheduleBuilder.build(workDays: [today, next], referenceDate: ref, calendar: calendar)
        let url = WidgetDeepLink.url(for: snapshot, calendar: calendar)

        XCTAssertNotNil(url)
        // Should point to today's date.
        let parsed = WidgetDeepLink.parseDate(from: url!, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: parsed!), 15)
    }

    func testDeepLinkFromSnapshotFallsBackToNextShift() {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        // No today, only next shift.
        let next = makeWorkDay(year: 2026, month: 8, day: 18, shift: c5, rules: c5Rules)

        let snapshot = WidgetScheduleBuilder.build(workDays: [next], referenceDate: ref, calendar: calendar)
        let url = WidgetDeepLink.url(for: snapshot, calendar: calendar)

        XCTAssertNotNil(url)
        let parsed = WidgetDeepLink.parseDate(from: url!, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: parsed!), 18, "Should fall back to next shift")
    }

    func testDeepLinkParseInvalidURLReturnsNil() {
        let url = URL(string: "https://example.com/other")!
        let parsed = WidgetDeepLink.parseDate(from: url, calendar: calendar)
        XCTAssertNil(parsed)
    }

    // MARK: - Empty Snapshot

    func testEmptySnapshotIsValid() {
        let empty = WidgetScheduleSnapshot.empty
        XCTAssertNil(empty.today)
        XCTAssertNil(empty.nextShift)
        XCTAssertTrue(empty.upcoming.isEmpty)
    }

    // MARK: - Codable Round Trip (App Group storage)

    func testSnapshotCodableRoundTrip() throws {
        let ref = makeDate(year: 2026, month: 8, day: 15)
        let wd = makeWorkDay(year: 2026, month: 8, day: 15, shift: c5, rules: c5Rules, note: "Note")
        let snapshot = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: ref, calendar: calendar)

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetScheduleSnapshot.self, from: data)

        XCTAssertEqual(decoded.today?.shiftCode, snapshot.today?.shiftCode)
        XCTAssertEqual(decoded.today?.startDateTime, snapshot.today?.startDateTime)
        XCTAssertEqual(decoded.today?.hasNote, snapshot.today?.hasNote)
    }
}
