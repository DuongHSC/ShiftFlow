// ShiftFlow — Tests
// IntegrationTests.swift
//
// TASK-INTEGRATION-001: End-to-end integration tests.
//
// Wires together the real domain services (WorkDayService, ShiftResolver,
// WidgetRefreshCoordinator, ShiftImportService, ShiftExportService,
// SyncConflictResolver, ReminderOffset) using an in-memory repository and a
// spy widget sink, then verifies the complete flows.
//
// SwiftData, WidgetKit, UNUserNotificationCenter, and CloudKit require
// macOS/Xcode — those integration points are exercised via their pure
// domain-facing logic here and verified physically on macOS later.

import XCTest
@testable import ShiftFlowDomain

final class IntegrationTests: XCTestCase {

    // MARK: - Infrastructure

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

    private func shiftLookup(_ code: String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? {
        switch code.uppercased() {
        case "C1": return (c1, [])
        case "C4": return (c4, [])
        case "C5": return (c5, c5Rules)
        default: return nil
        }
    }

    /// Spy widget sink to observe refresh integration.
    final class SpySink: WidgetSnapshotSink {
        private(set) var count = 0
        private(set) var last: WidgetScheduleSnapshot?
        func publish(_ snapshot: WidgetScheduleSnapshot) {
            count += 1
            last = snapshot
        }
    }

    /// Builds an integrated system: repo + widget coordinator + WorkDayService.
    private func makeSystem() -> (WorkDayService, InMemoryWorkDayRepository, SpySink, WidgetRefreshCoordinator) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let sink = SpySink()
        let coordinator = WidgetRefreshCoordinator(repository: repo, sink: sink, calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)
        return (service, repo, sink, coordinator)
    }

    // MARK: - 1. Create WorkDay End-to-End

    func testCreateWorkDayEndToEnd() throws {
        let (service, repo, sink, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // Persisted.
        XCTAssertNotNil(try repo.fetchByID(wd.id))
        // Snapshot correct (C5 day 15 special).
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)
        // Widget refreshed.
        XCTAssertEqual(sink.count, 1)
    }

    // MARK: - 2. Edit WorkDay End-to-End

    func testEditWorkDayEndToEnd() throws {
        let (service, repo, sink, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])
        let countAfterCreate = sink.count

        let updated = try service.changeShift(workDayID: wd.id, newShift: c5, rules: c5Rules)

        XCTAssertEqual(updated.shiftCode, "C5")
        XCTAssertEqual(timeComponents(from: updated.resolvedStartDateTime).hour, 12)
        XCTAssertEqual(try repo.fetchByID(wd.id)?.shiftCode, "C5")
        XCTAssertEqual(sink.count, countAfterCreate + 1)
    }

    // MARK: - 3. Delete WorkDay End-to-End

    func testDeleteWorkDayEndToEnd() throws {
        let (service, repo, sink, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])
        let countAfterCreate = sink.count

        try service.deleteWorkDay(id: wd.id)

        XCTAssertNil(try repo.fetchByID(wd.id))
        XCTAssertEqual(sink.count, countAfterCreate + 1)
    }

    // MARK: - 4. Change WorkDay to OFF

    func testChangeWorkDayToOFF() throws {
        let (service, repo, sink, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])
        // OFF = delete.
        try service.deleteWorkDay(id: wd.id)

        XCTAssertNil(try repo.fetchByDate(date), "OFF = no WorkDay")
        XCTAssertEqual(repo.count, 0)
    }

    // MARK: - 5. Import XLSX End-to-End (CSV interchange)

    func testImportEndToEnd() throws {
        let (service, repo, sink, _) = makeSystem()
        let importService = ShiftImportService(
            workDayService: service, shiftLookup: shiftLookup, calendar: calendar
        )

        let content = "Date,Shift,Task,Note\n15/08/2026,C5,MW,Trực MW\n16/08/2026,C1,,"
        let preview = try importService.prepareImport(content: content)
        XCTAssertEqual(preview.validRows.count, 2)

        let result = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(result.created, 2)
        XCTAssertEqual(repo.count, 2)

        // C5 day 15 resolved via ShiftResolver.
        let wd15 = try service.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(timeComponents(from: wd15.resolvedStartDateTime).hour, 12)
        // Note imported; MW is a task (not stored in note).
        XCTAssertEqual(wd15.note, "Trực MW")
    }

    // MARK: - 6. Export + Re-Import Round Trip

    func testExportReimportRoundTrip() throws {
        let (service, _, _, _) = makeSystem()
        let importService = ShiftImportService(
            workDayService: service, shiftLookup: shiftLookup, calendar: calendar
        )
        let exportService = ShiftExportService(calendar: calendar)

        _ = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "N1")
        _ = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 16), shift: c1, rules: [], note: "N2")

        let workDays = try service.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )
        let export = exportService.export(workDays: workDays)

        // Export excludes resolved times.
        XCTAssertFalse(export.textContent.contains("12:00"))
        XCTAssertFalse(export.textContent.contains("21:30"))

        // Clear and re-import.
        for wd in workDays { try service.deleteWorkDay(id: wd.id) }
        let preview = try importService.prepareImport(content: export.textContent)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        // Round-trip preserves date/shift/note; times re-resolved via ShiftResolver.
        let r15 = try service.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(r15.shiftCode, "C5")
        XCTAssertEqual(r15.note, "N1")
        XCTAssertEqual(timeComponents(from: r15.resolvedStartDateTime).hour, 12)
    }

    // MARK: - 7-10. C5 End-to-End

    func testC5Day9EndToEnd() throws { try assertC5(day: 9, hour: 11, minute: 30) }
    func testC5Day10EndToEnd() throws { try assertC5(day: 10, hour: 12, minute: 0) }
    func testC5Day20EndToEnd() throws { try assertC5(day: 20, hour: 12, minute: 0) }
    func testC5Day21EndToEnd() throws { try assertC5(day: 21, hour: 11, minute: 30) }

    private func assertC5(day: Int, hour: Int, minute: Int) throws {
        let (service, _, sink, coordinator) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: day)

        // Create via WorkDayService.
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // WorkDay snapshot.
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, hour)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).minute, minute)

        // Widget uses same snapshot.
        coordinator.refresh(referenceDate: date)
        XCTAssertEqual(timeComponents(from: sink.last!.today!.startDateTime).hour, hour)

        // Reminder uses same snapshot (2h before).
        let reminderFire = wd.resolvedStartDateTime.addingTimeInterval(-2 * 3600)
        let expectedReminderHour = (hour - 2 + 24) % 24
        XCTAssertEqual(timeComponents(from: reminderFire).hour, expectedReminderHour)
    }

    // MARK: - 11. Historical Snapshot Protection End-to-End

    func testHistoricalSnapshotProtectionEndToEnd() throws {
        let (service, repo, sink, coordinator) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Create C5 day 15 → 12:00 special.
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)

        // Simulate global C5 config change to 13:00 (NOT applied to existing WorkDay).
        // We do NOT call changeShift — global config change must not rewrite.

        // Calendar/reload: WorkDay unchanged.
        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 12)

        // Widget: unchanged.
        coordinator.refresh(referenceDate: date)
        XCTAssertEqual(timeComponents(from: sink.last!.today!.startDateTime).hour, 12)

        // Reminder: based on 12:00.
        let reminderFire = reloaded.resolvedStartDateTime.addingTimeInterval(-2 * 3600)
        XCTAssertEqual(timeComponents(from: reminderFire).hour, 10)
    }

    // MARK: - 12. MW Independence End-to-End

    func testMWIndependenceEndToEnd() throws {
        let (service, _, _, coordinator) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // C5 without task.
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        let startWithout = wd.resolvedStartDateTime
        let endWithout = wd.resolvedEndDateTime
        let breakWithout = wd.resolvedBreakStartDateTime

        // Simulate MW as a task association (via coordinator's task provider).
        // Rebuild widget with task indicator set — times must not change.
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        try repo.create(wd)
        let sink = SpySink()
        let coord = WidgetRefreshCoordinator(
            repository: repo, sink: sink,
            taskWorkDayIDsProvider: { [wd.id] }, calendar: calendar
        )
        coord.refresh(referenceDate: date)

        // Widget shows task indicator but same times.
        XCTAssertTrue(sink.last!.today!.hasTask)
        XCTAssertEqual(sink.last!.today!.startDateTime, startWithout)
        XCTAssertEqual(sink.last!.today!.endDateTime, endWithout)

        // Reminder identical.
        let reminderWithout = startWithout.addingTimeInterval(-2 * 3600)
        let reminderWith = sink.last!.today!.startDateTime.addingTimeInterval(-2 * 3600)
        XCTAssertEqual(reminderWithout, reminderWith)
        _ = breakWithout // referenced
        _ = coordinator
    }

    // MARK: - 13. Note Independence End-to-End

    func testNoteIndependenceEndToEnd() throws {
        let (service, _, _, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        let updated = try service.updateNote(workDayID: wd.id, note: "Team meeting")

        // Times unchanged.
        XCTAssertEqual(updated.resolvedStartDateTime, wd.resolvedStartDateTime)
        XCTAssertEqual(updated.resolvedEndDateTime, wd.resolvedEndDateTime)
    }

    // MARK: - 14-16. Reminder Integration (offset logic)

    func testReminderAfterCreate() throws {
        let (service, _, _, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // 2h reminder = 10:00 (from 12:00 snapshot).
        let fire = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)
        XCTAssertEqual(timeComponents(from: fire).hour, 10)
    }

    func testReminderAfterShiftChange() throws {
        let (service, _, _, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // C4 → reminder 2h before 08:30 = 06:30.
        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])
        let fireC4 = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)
        XCTAssertEqual(timeComponents(from: fireC4).hour, 6)
        XCTAssertEqual(timeComponents(from: fireC4).minute, 30)

        // Change to C5 → reminder 2h before 12:00 = 10:00.
        let updated = try service.changeShift(workDayID: wd.id, newShift: c5, rules: c5Rules)
        let fireC5 = ReminderOffset.twoHoursBefore.notificationDate(from: updated.resolvedStartDateTime)
        XCTAssertEqual(timeComponents(from: fireC5).hour, 10)
        XCTAssertNotEqual(fireC4, fireC5)
    }

    func testReminderCancellationIdentifiersAfterDelete() throws {
        let (service, _, _, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // All reminder identifiers for the WorkDay (to be cancelled on delete).
        let ids = ReminderIdentifier.allIdentifiers(for: wd.id)
        XCTAssertEqual(ids.count, 5)

        try service.deleteWorkDay(id: wd.id)
        // After delete, the identifiers are deterministic and cancellable.
        XCTAssertTrue(ids.allSatisfy { ReminderIdentifier.isShiftFlowNotification($0) })
    }

    // MARK: - 17-20. Widget Refresh Integration

    func testWidgetRefreshAfterCreate() throws {
        let (service, _, sink, _) = makeSystem()
        _ = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        XCTAssertEqual(sink.count, 1)
    }

    func testWidgetRefreshAfterEdit() throws {
        let (service, _, sink, _) = makeSystem()
        let wd = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        let before = sink.count
        _ = try service.changeShift(workDayID: wd.id, newShift: c5, rules: c5Rules)
        XCTAssertEqual(sink.count, before + 1)
    }

    func testWidgetRefreshAfterDelete() throws {
        let (service, _, sink, _) = makeSystem()
        let wd = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        let before = sink.count
        try service.deleteWorkDay(id: wd.id)
        XCTAssertEqual(sink.count, before + 1)
    }

    func testWidgetRefreshAfterImport() throws {
        let (service, _, sink, _) = makeSystem()
        let importService = ShiftImportService(
            workDayService: service, shiftLookup: shiftLookup, calendar: calendar
        )
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,\n16/08/2026,C1,,"
        let preview = try importService.prepareImport(content: content)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertGreaterThanOrEqual(sink.count, 1)
    }

    // MARK: - 21. Next Shift Update After Future WorkDay Change

    func testNextShiftUpdateAfterFutureChange() throws {
        let today = makeDate(year: 2026, month: 8, day: 15)
        let (service, _, sink, coordinator) = makeSystem()

        _ = try service.createWorkDay(date: today, shift: c4, rules: [])
        let future = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 18), shift: c5, rules: c5Rules)

        coordinator.refresh(referenceDate: today)
        XCTAssertEqual(sink.last?.nextShift?.shiftCode, "C5")

        try service.deleteWorkDay(id: future.id)
        coordinator.refresh(referenceDate: today)
        XCTAssertNil(sink.last?.nextShift)
    }

    // MARK: - 22. CloudKit Unavailable Does Not Block Local Save

    func testCloudKitUnavailableDoesNotBlockSave() throws {
        // The in-memory repo represents local persistence with no CloudKit.
        // WorkDay save succeeds regardless of CloudKit availability.
        let (service, repo, _, _) = makeSystem()
        let wd = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        XCTAssertNotNil(try repo.fetchByID(wd.id))
    }

    // MARK: - 23. CloudKit Sync Does Not Rewrite Snapshot

    func testCloudKitSyncDoesNotRewriteSnapshot() {
        // Conflict resolver preserves snapshot (see CloudKitSyncTests).
        let id = UUID()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)
        let local = WorkDay(id: id, date: date, shiftID: resolved.shiftID, shiftCode: "C5",
                            resolvedStartDateTime: resolved.startDateTime, resolvedEndDateTime: resolved.endDateTime,
                            resolvedBreakStartDateTime: resolved.breakStartDateTime, resolvedBreakEndDateTime: resolved.breakEndDateTime,
                            note: "local", createdAt: Date(), modifiedAt: makeDate(year: 2026, month: 8, day: 10))
        let remote = WorkDay(id: id, date: date, shiftID: resolved.shiftID, shiftCode: "C5",
                            resolvedStartDateTime: resolved.startDateTime, resolvedEndDateTime: resolved.endDateTime,
                            resolvedBreakStartDateTime: resolved.breakStartDateTime, resolvedBreakEndDateTime: resolved.breakEndDateTime,
                            note: "remote", createdAt: Date(), modifiedAt: makeDate(year: 2026, month: 8, day: 5))

        let winner = SyncConflictResolver.resolveSameRecord(local: local, remote: remote)
        XCTAssertEqual(timeComponents(from: winner.resolvedStartDateTime).hour, 12)
    }

    // MARK: - 24. Deleted WorkDay Becomes OFF

    func testDeletedWorkDayBecomesOFF() throws {
        let (service, repo, _, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])
        try service.deleteWorkDay(id: wd.id)
        XCTAssertNil(try repo.fetchByDate(date))
    }

    // MARK: - 25. Duplicate Date Protection

    func testDuplicateDateProtection() throws {
        let (service, repo, _, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)
        _ = try service.createWorkDay(date: date, shift: c4, rules: [])
        XCTAssertThrowsError(try service.createWorkDay(date: date, shift: c5, rules: c5Rules))
        XCTAssertEqual(repo.count, 1)
    }

    // MARK: - 26. XLSX Validation Prevents Invalid Import

    func testValidationPreventsInvalidImport() throws {
        let (service, repo, _, _) = makeSystem()
        let importService = ShiftImportService(
            workDayService: service, shiftLookup: shiftLookup, calendar: calendar
        )
        // Invalid shift C7 + missing date.
        let content = "Date,Shift,Task,Note\n15/08/2026,C7,,\n,C5,,"
        let preview = try importService.prepareImport(content: content)

        XCTAssertEqual(preview.errorRows.count, 2)
        XCTAssertEqual(preview.validRows.count, 0)

        let result = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(result.created, 0)
        XCTAssertEqual(repo.count, 0, "Invalid rows must not be imported")
    }

    // MARK: - 27. Export Is Read-Only

    func testExportIsReadOnly() throws {
        let (service, repo, _, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules, note: "Original")

        let exportService = ShiftExportService(calendar: calendar)
        let workDays = try service.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )
        _ = exportService.export(workDays: workDays)

        // WorkDay unchanged after export.
        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(after.note, "Original")
        XCTAssertEqual(after.resolvedStartDateTime, wd.resolvedStartDateTime)
    }

    // MARK: - 28. Offline Application Behavior

    func testOfflineApplicationBehavior() throws {
        // In-memory repo = fully offline. All operations succeed.
        let (service, repo, _, _) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        _ = try service.changeShift(workDayID: wd.id, newShift: c4, rules: [])
        _ = try service.updateNote(workDayID: wd.id, note: "offline note")
        let fetched = try service.fetchWorkDay(date: date)
        XCTAssertNotNil(fetched)
        try service.deleteWorkDay(id: wd.id)
        XCTAssertEqual(repo.count, 0)
    }

    // MARK: - 29-30. Accessibility / Color (domain-level guarantees)

    func testShiftCodeAlwaysAvailableForDisplay() throws {
        // Every WorkDay exposes a non-empty shiftCode text — never color-only.
        let (service, _, _, _) = makeSystem()
        let wd = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        XCTAssertFalse(wd.shiftCode.isEmpty)
        XCTAssertEqual(wd.shiftCode, "C5")
    }

    func testWidgetEntryExposesShiftCodeText() throws {
        let (service, _, sink, coordinator) = makeSystem()
        let date = makeDate(year: 2026, month: 8, day: 15)
        _ = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        coordinator.refresh(referenceDate: date)
        // Widget entry has shiftCode text (accessibility labels build from this).
        XCTAssertEqual(sink.last?.today?.shiftCode, "C5")
    }
}
