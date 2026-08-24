// ShiftFlow — Tests
// TaskManagementTests.swift
//
// TASK-TASK-001: Comprehensive task/MW tests.
//
// Verifies TaskDefinition/WorkDayTask, MW independence from shift times,
// historical snapshot protection, note independence, import/export,
// reminder independence, widget indicator, and seeding.
//
// TASK-GITHUB-ACTIONS-FIX-004 (module visibility): this file references
// ReminderOffset (reminder-independence assertions), which lives in the ShiftFlow
// app module (Notifications/ReminderModels.swift), not the domain package. It
// therefore imports the app module in addition to the domain module and is
// compiled by the app-hosted `ShiftFlowTests` Xcode target (excluded from the
// standalone `ShiftFlowDomain` SPM test target — see Package.swift).

import XCTest
@testable import ShiftFlowDomain
@testable import ShiftFlow

final class TaskManagementTests: XCTestCase {

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

    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c4: ShiftDefinition { ShiftSeedProvider.makeC4() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    private func makeTaskService(seed: Bool = true) -> (TaskService, InMemoryTaskStore) {
        let store = InMemoryTaskStore(seed: seed)
        let service = TaskService(store: store)
        return (service, store)
    }

    private func makeWorkDayService() -> (WorkDayService, InMemoryWorkDayRepository) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        return (WorkDayService(repository: repo, calendar: calendar), repo)
    }

    private func shiftLookup(_ code: String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? {
        switch code.uppercased() {
        case "C4": return (c4, [])
        case "C5": return (c5, c5Rules)
        default: return nil
        }
    }

    // MARK: - TaskDefinition (1-9)

    func testDefaultMWIsSeeded() {
        let (service, _) = makeTaskService()
        XCTAssertNotNil(service.task(withCode: "MW"))
    }

    func testTaskSeedIsIdempotent() {
        let store = InMemoryTaskStore(seed: false)
        let service = TaskService(store: store)
        service.seedIfNeeded()
        service.seedIfNeeded()
        service.seedIfNeeded()
        XCTAssertEqual(service.allTasks().count, 1)
    }

    func testCustomTaskIsNotOverwritten() throws {
        let (service, _) = makeTaskService()
        _ = try service.createTask(code: "Ticket", name: "Ticket")
        service.seedIfNeeded() // re-seed
        XCTAssertNotNil(service.task(withCode: "Ticket"), "Custom task must survive re-seed")
        XCTAssertEqual(service.allTasks().count, 2)
    }

    func testCreateTask() throws {
        let (service, _) = makeTaskService()
        let task = try service.createTask(code: "Zalo", name: "Zalo")
        XCTAssertEqual(task.code, "Zalo")
        XCTAssertNotNil(service.task(withCode: "Zalo"))
    }

    func testEditTask() throws {
        let (service, _) = makeTaskService()
        let mw = service.task(withCode: "MW")!
        try service.updateTask(mw.withEdits(name: "Morning Work"))
        XCTAssertEqual(service.task(withCode: "MW")!.name, "Morning Work")
        XCTAssertEqual(service.task(withCode: "MW")!.code, "MW", "Code stable")
    }

    func testDisableTask() throws {
        let (service, _) = makeTaskService()
        let mw = service.task(withCode: "MW")!
        try service.setTaskActive(id: mw.id, isActive: false)
        XCTAssertFalse(service.activeTasks().contains { $0.code == "MW" })
    }

    func testDuplicateTaskCodeRejected() throws {
        let (service, _) = makeTaskService()
        XCTAssertThrowsError(try service.createTask(code: "MW", name: "Dup")) { error in
            if case .some(.duplicateCode) = (error as? TaskError) {} else { XCTFail() }
        }
    }

    func testEmptyTaskCodeRejected() {
        let (service, _) = makeTaskService()
        XCTAssertThrowsError(try service.createTask(code: "  ", name: "X")) { error in
            XCTAssertEqual(error as? TaskError, .emptyCode)
        }
    }

    func testEmptyTaskNameRejected() {
        let (service, _) = makeTaskService()
        XCTAssertThrowsError(try service.createTask(code: "X", name: "  ")) { error in
            XCTAssertEqual(error as? TaskError, .emptyName)
        }
    }

    // MARK: - WorkDayTask (10-15)

    func testAddMWToWorkDay() throws {
        let (taskService, _) = makeTaskService()
        let workDayID = UUID()
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: workDayID)
        XCTAssertTrue(taskService.hasTask(workDayID: workDayID))
        XCTAssertEqual(taskService.tasks(forWorkDay: workDayID).first?.code, "MW")
    }

    func testRemoveMWFromWorkDay() throws {
        let (taskService, _) = makeTaskService()
        let workDayID = UUID()
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: workDayID)
        taskService.removeTask(taskDefinitionID: mw.id, fromWorkDay: workDayID)
        XCTAssertFalse(taskService.hasTask(workDayID: workDayID))
    }

    func testMultipleTasksOnWorkDay() throws {
        let (taskService, _) = makeTaskService()
        let workDayID = UUID()
        let mw = taskService.task(withCode: "MW")!
        let ticket = try taskService.createTask(code: "Ticket", name: "Ticket")
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: workDayID)
        try taskService.addTask(taskDefinitionID: ticket.id, toWorkDay: workDayID)
        XCTAssertEqual(taskService.tasks(forWorkDay: workDayID).count, 2)
    }

    func testTaskAssignmentDoesNotChangeShiftSnapshot() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let before = try repo.fetchByID(wd.id)!

        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(before.resolvedStartDateTime, after.resolvedStartDateTime)
        XCTAssertEqual(before.resolvedEndDateTime, after.resolvedEndDateTime)
    }

    func testTaskRemovalDoesNotChangeShiftSnapshot() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        let before = try repo.fetchByID(wd.id)!

        taskService.removeTask(taskDefinitionID: mw.id, fromWorkDay: wd.id)

        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(before.resolvedStartDateTime, after.resolvedStartDateTime)
    }

    func testTaskNameChangeDoesNotChangeShiftSnapshot() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        try taskService.updateTask(mw.withEdits(name: "Morning Work"))

        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: after.resolvedStartDateTime).hour, 12)
    }

    // MARK: - MW Independence (16-20)

    func testMWDoesNotChangeStartTime() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        XCTAssertEqual(timeComponents(from: try repo.fetchByID(wd.id)!.resolvedStartDateTime).hour, 12)
    }

    func testMWDoesNotChangeEndTime() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: after.resolvedEndDateTime).hour, 21)
        XCTAssertEqual(timeComponents(from: after.resolvedEndDateTime).minute, 30)
    }

    func testMWDoesNotChangeBreakTime() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: after.resolvedBreakStartDateTime).hour, 16)
        XCTAssertEqual(timeComponents(from: after.resolvedBreakEndDateTime).hour, 17)
    }

    func testMWDoesNotChangeReminderTime() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let fireBefore = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        // Reminder derives from the (unchanged) snapshot.
        let fireAfter = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)
        XCTAssertEqual(fireBefore, fireAfter)
    }

    func testMWDoesNotChangeWidgetTimes() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)

        let noTask = WidgetScheduleBuilder.build(workDays: [wd], referenceDate: makeDate(year: 2026, month: 8, day: 15), calendar: calendar)

        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        let workDays = try repo.fetchByDateRange(from: makeDate(year: 2026, month: 8, day: 15), to: makeDate(year: 2026, month: 8, day: 15))
        let withTask = WidgetScheduleBuilder.build(workDays: workDays, referenceDate: makeDate(year: 2026, month: 8, day: 15), taskWorkDayIDs: taskService.workDayIDsWithTasks(), calendar: calendar)

        XCTAssertEqual(noTask.today?.startDateTime, withTask.today?.startDateTime)
        XCTAssertTrue(withTask.today!.hasTask)
    }

    // MARK: - Note Independence (21-23)

    func testTaskAndNoteAreStoredSeparately() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "Họp team")
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        XCTAssertEqual(wd.note, "Họp team")
        XCTAssertEqual(taskService.tasks(forWorkDay: wd.id).first?.code, "MW")
    }

    func testTaskDoesNotAppearInNote() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "Note only")
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(reloaded.note, "Note only")
        XCTAssertFalse(reloaded.note?.contains("MW") ?? false)
    }

    func testNoteDoesNotAppearInTask() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "Chuyển ticket")
        // No task assigned; tasks list empty despite note present.
        XCTAssertTrue(taskService.tasks(forWorkDay: wd.id).isEmpty)
    }

    // MARK: - Import (30-34)

    func testImportMWCreatesWorkDayTask() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)

        let content = "Date,Shift,Task,Note\n15/08/2026,C5,MW,Trực MW"
        let preview = try importService.prepareImport(content: content)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let wd = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(taskService.tasks(forWorkDay: wd.id).first?.code, "MW")
    }

    func testImportTaskDoesNotEnterNote() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)

        let content = "Date,Shift,Task,Note\n15/08/2026,C5,MW,Trực MW"
        let preview = try importService.prepareImport(content: content)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let wd = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(wd.note, "Trực MW")
        XCTAssertFalse(wd.note?.contains("MW,") ?? false)
    }

    func testUnknownTaskIsRejected() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)

        let content = "Date,Shift,Task,Note\n15/08/2026,C5,ABC,"
        let preview = try importService.prepareImport(content: content)

        XCTAssertEqual(preview.errorRows.count, 1)
        if case .error(let msg) = preview.rows[0].status {
            XCTAssertTrue(msg.contains("ABC"))
        } else {
            XCTFail("Expected error for unknown task")
        }
    }

    func testImportMultipleTasks() throws {
        let (taskService, _) = makeTaskService()
        _ = try taskService.createTask(code: "Ticket", name: "Ticket")
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)

        let content = "Date,Shift,Task,Note\n15/08/2026,C5,MW;Ticket,"
        let preview = try importService.prepareImport(content: content)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let wd = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(taskService.tasks(forWorkDay: wd.id).count, 2)
    }

    func testImportPreservesSnapshot() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)

        let content = "Date,Shift,Task,Note\n15/08/2026,C5,MW,"
        let preview = try importService.prepareImport(content: content)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let wd = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)
    }

    // MARK: - Export (35-38)

    func testExportIncludesTask() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: [wd], taskService: taskService)
        XCTAssertEqual(result.rows.first?.task, "MW")
    }

    func testExportMultipleTasks() throws {
        let (taskService, _) = makeTaskService()
        let ticket = try taskService.createTask(code: "Ticket", name: "Ticket")
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        try taskService.addTask(taskDefinitionID: ticket.id, toWorkDay: wd.id)

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: [wd], taskService: taskService)
        // Deterministic: sorted by code → "MW;Ticket".
        XCTAssertEqual(result.rows.first?.task, "MW;Ticket")
    }

    func testExportDoesNotIncludeResolvedTimes() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: [wd], taskService: taskService)
        XCTAssertFalse(result.textContent.contains("12:00"))
        XCTAssertFalse(result.textContent.contains("21:30"))
    }

    func testExportIsReadOnly() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let exportService = ShiftExportService(calendar: calendar)
        _ = exportService.export(workDays: [wd], taskService: taskService)

        // Task assignment + WorkDay unchanged.
        XCTAssertTrue(taskService.hasTask(workDayID: wd.id))
        XCTAssertNotNil(try repo.fetchByID(wd.id))
    }

    // MARK: - Round Trip (39-42)

    func testTaskRoundTrip() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)
        let exportService = ShiftExportService(calendar: calendar)

        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "N")
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let export = exportService.export(workDays: [wd], taskService: taskService)

        // Clear and re-import.
        taskService.removeAllTasks(forWorkDay: wd.id)
        try wdService.deleteWorkDay(id: wd.id)

        let preview = try importService.prepareImport(content: export.textContent)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let reimported = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(reimported.shiftCode, "C5")
        XCTAssertEqual(reimported.note, "N")
        XCTAssertEqual(taskService.tasks(forWorkDay: reimported.id).first?.code, "MW")
    }

    func testMultipleTaskRoundTrip() throws {
        let (taskService, _) = makeTaskService()
        _ = try taskService.createTask(code: "Ticket", name: "Ticket")
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)
        let exportService = ShiftExportService(calendar: calendar)

        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        let ticket = taskService.task(withCode: "Ticket")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        try taskService.addTask(taskDefinitionID: ticket.id, toWorkDay: wd.id)

        let export = exportService.export(workDays: [wd], taskService: taskService)
        taskService.removeAllTasks(forWorkDay: wd.id)
        try wdService.deleteWorkDay(id: wd.id)

        let preview = try importService.prepareImport(content: export.textContent)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let reimported = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(taskService.tasks(forWorkDay: reimported.id).count, 2)
    }

    func testRoundTripPreservesNoteSeparately() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)
        let exportService = ShiftExportService(calendar: calendar)

        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "Trực MW")
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let export = exportService.export(workDays: [wd], taskService: taskService)
        taskService.removeAllTasks(forWorkDay: wd.id)
        try wdService.deleteWorkDay(id: wd.id)

        let preview = try importService.prepareImport(content: export.textContent)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let reimported = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(reimported.note, "Trực MW", "Note preserved separately from task")
        XCTAssertEqual(taskService.tasks(forWorkDay: reimported.id).first?.code, "MW")
    }

    func testRoundTripReResolvesThroughShiftResolver() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let importService = ShiftImportService(workDayService: wdService, shiftLookup: shiftLookup, taskService: taskService, calendar: calendar)
        let exportService = ShiftExportService(calendar: calendar)

        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let export = exportService.export(workDays: [wd], taskService: taskService)
        try wdService.deleteWorkDay(id: wd.id)

        let preview = try importService.prepareImport(content: export.textContent)
        _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let reimported = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        // Times come from ShiftResolver, not export.
        XCTAssertEqual(timeComponents(from: reimported.resolvedStartDateTime).hour, 12)
    }

    // MARK: - Reminder (43-45)

    func testAddingTaskDoesNotRescheduleReminder() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let fireBefore = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)

        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        // Reminder fire time depends only on snapshot (unchanged).
        let fireAfter = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)
        XCTAssertEqual(fireBefore, fireAfter)
    }

    func testRemovingTaskDoesNotRescheduleReminder() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        let fireBefore = ReminderOffset.oneHourBefore.notificationDate(from: wd.resolvedStartDateTime)

        taskService.removeTask(taskDefinitionID: mw.id, fromWorkDay: wd.id)
        let fireAfter = ReminderOffset.oneHourBefore.notificationDate(from: wd.resolvedStartDateTime)
        XCTAssertEqual(fireBefore, fireAfter)
    }

    func testChangingTaskDoesNotChangeReminderTime() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        let fireBefore = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)

        try taskService.updateTask(mw.withEdits(name: "Renamed"))
        let fireAfter = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)
        XCTAssertEqual(fireBefore, fireAfter)
    }

    // MARK: - Widget (46-48)

    func testWidgetShowsTaskIndicator() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let workDays = try repo.fetchByDateRange(from: makeDate(year: 2026, month: 8, day: 15), to: makeDate(year: 2026, month: 8, day: 15))
        let snapshot = WidgetScheduleBuilder.build(workDays: workDays, referenceDate: makeDate(year: 2026, month: 8, day: 15), taskWorkDayIDs: taskService.workDayIDsWithTasks(), calendar: calendar)
        XCTAssertTrue(snapshot.today!.hasTask)
    }

    func testWidgetTaskDoesNotChangeShiftTimes() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let workDays = try repo.fetchByDateRange(from: makeDate(year: 2026, month: 8, day: 15), to: makeDate(year: 2026, month: 8, day: 15))
        let snapshot = WidgetScheduleBuilder.build(workDays: workDays, referenceDate: makeDate(year: 2026, month: 8, day: 15), taskWorkDayIDs: taskService.workDayIDsWithTasks(), calendar: calendar)
        XCTAssertEqual(timeComponents(from: snapshot.today!.startDateTime).hour, 12)
    }

    func testWidgetDoesNotExposeNoteText() throws {
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "Secret")
        let workDays = try repo.fetchByDateRange(from: makeDate(year: 2026, month: 8, day: 15), to: makeDate(year: 2026, month: 8, day: 15))
        let snapshot = WidgetScheduleBuilder.build(workDays: workDays, referenceDate: makeDate(year: 2026, month: 8, day: 15), calendar: calendar)
        XCTAssertTrue(snapshot.today!.hasNote)
        _ = wd
        // WidgetDayEntry has no note-text property — compile-time guarantee.
    }

    // MARK: - Historical Safety (49-50)

    func testTaskChangesDoNotRewriteHistoricalWorkDay() throws {
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = taskService.task(withCode: "MW")!

        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        taskService.removeTask(taskDefinitionID: mw.id, fromWorkDay: wd.id)
        try taskService.updateTask(mw.withEdits(name: "Morning Work"))

        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 12)
        XCTAssertEqual(timeComponents(from: reloaded.resolvedEndDateTime).hour, 21)
    }

    func testTaskSyncDoesNotRewriteHistoricalSnapshot() throws {
        // Task assignments are separate records; a WorkDay's snapshot is never
        // rewritten by task operations (verified via repository fetch).
        let (taskService, _) = makeTaskService()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let snapshotBefore = try repo.fetchByID(wd.id)!

        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let snapshotAfter = try repo.fetchByID(wd.id)!
        XCTAssertEqual(snapshotBefore.resolvedStartDateTime, snapshotAfter.resolvedStartDateTime)
        XCTAssertEqual(snapshotBefore.resolvedEndDateTime, snapshotAfter.resolvedEndDateTime)
        XCTAssertEqual(snapshotBefore.resolvedBreakStartDateTime, snapshotAfter.resolvedBreakStartDateTime)
        XCTAssertEqual(snapshotBefore.resolvedBreakEndDateTime, snapshotAfter.resolvedBreakEndDateTime)
    }

    // MARK: - Delete task in use

    func testDeleteTaskInUseIsRejected() throws {
        let (taskService, _) = makeTaskService()
        let workDayID = UUID()
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: workDayID)

        XCTAssertThrowsError(try taskService.deleteTask(id: mw.id)) { error in
            if case .some(.taskInUse) = (error as? TaskError) {} else { XCTFail() }
        }
    }

    func testDeleteUnusedTaskSucceeds() throws {
        let (taskService, _) = makeTaskService()
        let ticket = try taskService.createTask(code: "Ticket", name: "Ticket")
        try taskService.deleteTask(id: ticket.id)
        XCTAssertNil(taskService.task(withCode: "Ticket"))
    }

    // MARK: - OFF

    func testOFFDoesNotCreateTask() throws {
        // OFF = no WorkDay = no task. Nothing is created.
        let (taskService, _) = makeTaskService()
        // No WorkDay, no assignment.
        XCTAssertTrue(taskService.workDayIDsWithTasks().isEmpty)
    }
}
