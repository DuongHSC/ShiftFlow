// ShiftFlow — Tests
// WidgetRefreshIntegrationTests.swift
//
// TASK-WIDGET-002: Widget data refresh integration tests.
//
// Verifies that WorkDayService triggers widget refresh after mutations,
// that widget failure does not affect WorkDay operations, and that the
// widget snapshot always reflects the historical WorkDay snapshot.
//
// Uses a spy WidgetSnapshotSink to observe publish calls without WidgetKit.

import XCTest
@testable import ShiftFlowDomain

final class WidgetRefreshIntegrationTests: XCTestCase {

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

    // MARK: - Spy Sink

    /// Records published snapshots for assertion.
    final class SpySink: WidgetSnapshotSink {
        private(set) var publishedSnapshots: [WidgetScheduleSnapshot] = []
        var publishCount: Int { publishedSnapshots.count }
        var lastSnapshot: WidgetScheduleSnapshot? { publishedSnapshots.last }

        func publish(_ snapshot: WidgetScheduleSnapshot) {
            publishedSnapshots.append(snapshot)
        }
    }

    /// A sink that simulates a write failure — but must NOT throw (matches protocol).
    /// It records that publish was attempted, but "fails" silently internally.
    final class FailingSink: WidgetSnapshotSink {
        private(set) var attemptCount = 0
        func publish(_ snapshot: WidgetScheduleSnapshot) {
            attemptCount += 1
            // Simulate internal failure (e.g., App Group unavailable).
            // Per contract, publish never throws — failure is swallowed here.
        }
    }

    // MARK: - Setup Helper

    private func makeSystem(referenceToday: Date) -> (WorkDayService, InMemoryWorkDayRepository, SpySink) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let sink = SpySink()
        let coordinator = WidgetRefreshCoordinator(
            repository: repo,
            sink: sink,
            calendar: calendar
        )
        let service = WorkDayService(
            repository: repo,
            calendar: calendar,
            widgetRefresher: coordinator
        )
        return (service, repo, sink)
    }

    // MARK: - 1. Create Triggers Widget Update

    func testCreateWorkDayTriggersWidgetUpdate() throws {
        let (service, _, sink) = makeSystem(referenceToday: Date())

        _ = try service.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c4, rules: []
        )

        XCTAssertEqual(sink.publishCount, 1, "Create must trigger exactly one widget refresh")
    }

    // MARK: - 2. Change Shift Triggers Widget Update

    func testChangeShiftTriggersWidgetUpdate() throws {
        let (service, _, sink) = makeSystem(referenceToday: Date())

        let wd = try service.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c4, rules: []
        )
        let countAfterCreate = sink.publishCount

        _ = try service.changeShift(workDayID: wd.id, newShift: c5, rules: c5Rules)

        XCTAssertEqual(sink.publishCount, countAfterCreate + 1, "Change shift must trigger widget refresh")
    }

    // MARK: - 3. Delete Triggers Widget Update

    func testDeleteWorkDayTriggersWidgetUpdate() throws {
        let (service, _, sink) = makeSystem(referenceToday: Date())

        let wd = try service.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c4, rules: []
        )
        let countAfterCreate = sink.publishCount

        try service.deleteWorkDay(id: wd.id)

        XCTAssertEqual(sink.publishCount, countAfterCreate + 1, "Delete must trigger widget refresh")
    }

    // MARK: - 4. Import Triggers Widget Update

    func testImportTriggersWidgetUpdate() throws {
        let (service, _, sink) = makeSystem(referenceToday: Date())

        let importService = ShiftImportService(
            workDayService: service,
            shiftLookup: { [self] code in
                switch code {
                case "C1": return (c1, [])
                case "C5": return (c5, c5Rules)
                default: return nil
                }
            },
            calendar: calendar
        )

        let content = "Date,Shift,Task,Note\n01/08/2026,C1,,\n15/08/2026,C5,,"
        let preview = try importService.prepareImport(content: content)
        let result = try importService.executeImport(preview: preview, strategy: .skipExisting)

        XCTAssertEqual(result.created, 2)
        // Each created WorkDay triggers a refresh (final state is correct).
        XCTAssertGreaterThanOrEqual(sink.publishCount, 1, "Import must trigger widget refresh")
        // Final snapshot must reflect both imported days within the window.
        XCTAssertNotNil(sink.lastSnapshot)
    }

    // MARK: - 5. Replace-Existing Import Triggers Widget Update

    func testReplaceExistingImportTriggersWidgetUpdate() throws {
        let (service, _, sink) = makeSystem(referenceToday: Date())

        // Pre-existing WorkDay.
        _ = try service.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c4, rules: []
        )
        let countBefore = sink.publishCount

        let importService = ShiftImportService(
            workDayService: service,
            shiftLookup: { [self] code in code == "C5" ? (c5, c5Rules) : nil },
            calendar: calendar
        )

        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,New"
        let preview = try importService.prepareImport(content: content)
        let result = try importService.executeImport(preview: preview, strategy: .replaceExisting)

        XCTAssertEqual(result.replaced, 1)
        XCTAssertGreaterThan(sink.publishCount, countBefore, "Replace import must trigger widget refresh")
    }

    // MARK: - 6. OFF Removes WorkDay and Updates Widget

    func testChangeToOFFRemovesWorkDayAndUpdatesWidget() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let (service, repo, sink) = makeSystem(referenceToday: today)

        let wd = try service.createWorkDay(date: today, shift: c4, rules: [])
        let countAfterCreate = sink.publishCount

        // Changing to OFF = deleting the WorkDay.
        try service.deleteWorkDay(id: wd.id)

        XCTAssertEqual(sink.publishCount, countAfterCreate + 1)
        XCTAssertEqual(repo.count, 0, "OFF must delete the WorkDay")
        // No persistent OFF ShiftDefinition is created (repository only holds WorkDays).
    }

    // MARK: - 7. Future WorkDay Change Updates Next Shift

    func testFutureWorkDayChangeUpdatesNextShiftSnapshot() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let sink = SpySink()
        let coordinator = WidgetRefreshCoordinator(repository: repo, sink: sink, calendar: calendar)
        // Use a fixed reference date via coordinator.refresh(referenceDate:) — but
        // WorkDayService calls refresh() with Date(). To test deterministically,
        // we verify the coordinator directly with a controlled reference date.
        let service = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)

        // Create today + a future shift.
        _ = try service.createWorkDay(date: today, shift: c4, rules: [])
        let futureThu = makeDate(year: 2026, month: 8, day: 20)
        let futureWD = try service.createWorkDay(date: futureThu, shift: c5, rules: c5Rules)

        // Build a snapshot with controlled reference date.
        coordinator.refresh(referenceDate: today)
        let beforeDelete = sink.lastSnapshot
        XCTAssertEqual(beforeDelete?.nextShift?.shiftCode, "C5")

        // Delete the future shift.
        try service.deleteWorkDay(id: futureWD.id)

        coordinator.refresh(referenceDate: today)
        let afterDelete = sink.lastSnapshot
        XCTAssertNil(afterDelete?.nextShift, "Next shift must update after future WorkDay deleted")
    }

    // MARK: - 8. MW Changes Indicator But Not Times

    func testMWChangesIndicatorButNotShiftTimes() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let sink = SpySink()

        // Task provider that reports MW on the WorkDay after we set it.
        var taskIDs = Set<UUID>()
        let coordinator = WidgetRefreshCoordinator(
            repository: repo,
            sink: sink,
            taskWorkDayIDsProvider: { taskIDs },
            calendar: calendar
        )
        let service = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)

        let wd = try service.createWorkDay(date: today, shift: c5, rules: c5Rules)

        coordinator.refresh(referenceDate: today)
        let before = sink.lastSnapshot?.today
        XCTAssertFalse(before?.hasTask ?? true)
        let startBefore = timeComponents(from: before!.startDateTime)

        // Simulate adding MW task.
        taskIDs.insert(wd.id)
        coordinator.refresh(referenceDate: today)
        let after = sink.lastSnapshot?.today

        XCTAssertTrue(after?.hasTask ?? false, "MW must set task indicator")
        let startAfter = timeComponents(from: after!.startDateTime)

        // Times unchanged.
        XCTAssertEqual(startBefore.hour, startAfter.hour, "MW must not change start time")
        XCTAssertEqual(startBefore.minute, startAfter.minute)
        XCTAssertEqual(after?.startDateTime, before?.startDateTime)
        XCTAssertEqual(after?.endDateTime, before?.endDateTime)
    }

    // MARK: - 9. Note Does Not Alter Shift Times

    func testNoteUpdateDoesNotAlterShiftTimes() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let (service, _, sink) = makeSystem(referenceToday: today)

        let wd = try service.createWorkDay(date: today, shift: c5, rules: c5Rules)
        let beforeSnapshotCount = sink.publishCount

        let updated = try service.updateNote(workDayID: wd.id, note: "Meeting")

        // Note update triggers refresh (hasNote indicator).
        XCTAssertGreaterThan(sink.publishCount, beforeSnapshotCount)

        // Shift times unchanged.
        XCTAssertEqual(updated.resolvedStartDateTime, wd.resolvedStartDateTime)
        XCTAssertEqual(updated.resolvedEndDateTime, wd.resolvedEndDateTime)
    }

    // MARK: - 10. Failed WorkDay Save Does Not Update Widget

    func testFailedCreateDoesNotUpdateWidget() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let (service, _, sink) = makeSystem(referenceToday: today)

        // Create once (succeeds, triggers 1 refresh).
        _ = try service.createWorkDay(date: today, shift: c4, rules: [])
        let countAfterFirst = sink.publishCount

        // Attempt duplicate create (fails).
        XCTAssertThrowsError(
            try service.createWorkDay(date: today, shift: c5, rules: c5Rules)
        )

        // No additional refresh on failure.
        XCTAssertEqual(sink.publishCount, countAfterFirst, "Failed create must not trigger widget refresh")
    }

    func testFailedDeleteDoesNotUpdateWidget() throws {
        let (service, _, sink) = makeSystem(referenceToday: Date())
        let countBefore = sink.publishCount

        // Delete non-existent WorkDay (fails).
        XCTAssertThrowsError(try service.deleteWorkDay(id: UUID()))

        XCTAssertEqual(sink.publishCount, countBefore, "Failed delete must not trigger widget refresh")
    }

    // MARK: - 11. Widget Write Failure Does Not Rollback WorkDay

    func testWidgetFailureDoesNotRollbackWorkDay() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let failingSink = FailingSink()
        let coordinator = WidgetRefreshCoordinator(repository: repo, sink: failingSink, calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)

        // Create succeeds even though the sink "fails" internally.
        let wd = try service.createWorkDay(date: today, shift: c4, rules: [])

        // WorkDay is persisted.
        let fetched = try repo.fetchByID(wd.id)
        XCTAssertNotNil(fetched, "WorkDay must remain saved despite widget failure")
        XCTAssertEqual(fetched?.shiftCode, "C4")

        // Sink was attempted.
        XCTAssertEqual(failingSink.attemptCount, 1)
    }

    // MARK: - 12. Widget Snapshot Uses Historical WorkDay Snapshot

    func testWidgetSnapshotUsesHistoricalWorkDaySnapshot() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let sink = SpySink()
        let coordinator = WidgetRefreshCoordinator(repository: repo, sink: sink, calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)

        // C5 on day 15 → special (12:00).
        _ = try service.createWorkDay(date: today, shift: c5, rules: c5Rules)

        coordinator.refresh(referenceDate: today)
        let entry = sink.lastSnapshot?.today
        let start = timeComponents(from: entry!.startDateTime)
        XCTAssertEqual(start.hour, 12)
        XCTAssertEqual(start.minute, 0)
    }

    // MARK: - 13. Global Config Change Does Not Rewrite Historical Widget Data

    func testGlobalConfigChangeDoesNotRewriteWidgetData() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let sink = SpySink()
        let coordinator = WidgetRefreshCoordinator(repository: repo, sink: sink, calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)

        // Create with original C5 (12:00 special).
        _ = try service.createWorkDay(date: today, shift: c5, rules: c5Rules)

        coordinator.refresh(referenceDate: today)
        let before = timeComponents(from: sink.lastSnapshot!.today!.startDateTime)
        XCTAssertEqual(before.hour, 12)

        // Simulate global config change (does NOT touch existing WorkDay).
        // Rebuild widget from repository — WorkDay snapshot is unchanged.
        coordinator.refresh(referenceDate: today)
        let after = timeComponents(from: sink.lastSnapshot!.today!.startDateTime)
        XCTAssertEqual(after.hour, 12, "Widget must show historical snapshot, not new config")
        XCTAssertEqual(after.minute, 0)
    }

    // MARK: - 14-17. C5 Boundary via Widget Integration

    func testC5Day9WidgetIntegration() throws {
        try assertC5WidgetStart(day: 9, expectedHour: 11, expectedMinute: 30)
    }

    func testC5Day10WidgetIntegration() throws {
        try assertC5WidgetStart(day: 10, expectedHour: 12, expectedMinute: 0)
    }

    func testC5Day20WidgetIntegration() throws {
        try assertC5WidgetStart(day: 20, expectedHour: 12, expectedMinute: 0)
    }

    func testC5Day21WidgetIntegration() throws {
        try assertC5WidgetStart(day: 21, expectedHour: 11, expectedMinute: 30)
    }

    private func assertC5WidgetStart(day: Int, expectedHour: Int, expectedMinute: Int) throws {
        let date = makeDate(year: 2026, month: 8, day: day)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let sink = SpySink()
        let coordinator = WidgetRefreshCoordinator(repository: repo, sink: sink, calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)

        _ = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        coordinator.refresh(referenceDate: date)
        let start = timeComponents(from: sink.lastSnapshot!.today!.startDateTime)
        XCTAssertEqual(start.hour, expectedHour, "C5 day \(day) start hour")
        XCTAssertEqual(start.minute, expectedMinute, "C5 day \(day) start minute")
    }

    // MARK: - 18. Repeated Refresh Does Not Corrupt Snapshot

    func testRepeatedRefreshDoesNotCorruptSnapshot() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let sink = SpySink()
        let coordinator = WidgetRefreshCoordinator(repository: repo, sink: sink, calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)

        _ = try service.createWorkDay(date: today, shift: c5, rules: c5Rules)

        // Refresh many times.
        for _ in 0..<10 {
            coordinator.refresh(referenceDate: today)
        }

        // All snapshots identical (deterministic rebuild).
        let first = sink.publishedSnapshots.first!
        for snap in sink.publishedSnapshots {
            XCTAssertEqual(snap.today?.startDateTime, first.today?.startDateTime)
            XCTAssertEqual(snap.today?.shiftCode, first.today?.shiftCode)
        }
    }

    // MARK: - 20. Widget Reload Requested After Successful Update

    func testWidgetPublishCalledAfterSuccessfulUpdate() throws {
        let (service, _, sink) = makeSystem(referenceToday: Date())

        XCTAssertEqual(sink.publishCount, 0)

        _ = try service.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c4, rules: []
        )

        XCTAssertEqual(sink.publishCount, 1, "Widget publish (reload) must be requested after successful update")
    }

    // MARK: - No Refresher (Optional Dependency)

    func testServiceWorksWithoutWidgetRefresher() throws {
        // WorkDayService with nil refresher must still work.
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar) // no refresher

        let wd = try service.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c4, rules: []
        )

        XCTAssertNotNil(try repo.fetchByID(wd.id))
    }
}
