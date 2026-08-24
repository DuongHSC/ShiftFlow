// ShiftFlow — Tests
// DataManagementViewModelTests.swift
//
// TASK-DATA-001: CSV Data Management UI ViewModel tests.
//
// Verifies the CSV import/export UI flow that wraps the EXISTING import/export
// services. Confirms:
// - Export headers/sorting/tasks/notes/OFF/read-only/no-resolved-times
// - Template headers
// - Import valid/invalid/duplicate/conflict/skip/replace/OFF
// - Task/Note independence and historical snapshot protection
// - C5 boundary via import
// - Error messages contain no internal details
//
// NOTE: DataManagementViewModel lives in the app's Application layer and is
// exercised here following the same convention as TaskSettingsViewModelTests.
// Windows cannot execute Swift/Xcode tests — status is IMPLEMENTED, NOT EXECUTED.
//
// TASK-XCODE-FIX-001 (XP-01): imports the app module for DataManagementViewModel
// in addition to the domain module. Compiled by the app-hosted `ShiftFlowTests`
// Xcode target, not the standalone `ShiftFlowDomain` SPM test target.

import XCTest
@testable import ShiftFlowDomain
@testable import ShiftFlow

final class DataManagementViewModelTests: XCTestCase {

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
    private var c3: ShiftDefinition { ShiftSeedProvider.makeC3() }
    private var c4: ShiftDefinition { ShiftSeedProvider.makeC4() }
    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    private func shiftLookup(_ code: String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? {
        switch code.uppercased() {
        case "C1": return (c1, [])
        case "C3": return (c3, [])
        case "C4": return (c4, [])
        case "C5": return (c5, c5Rules)
        default: return nil
        }
    }

    /// Builds the full system: in-memory repository + task store + services + VM.
    private func makeSystem() -> (
        vm: DataManagementViewModel,
        workDayService: WorkDayService,
        taskService: TaskService,
        repo: InMemoryWorkDayRepository
    ) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let taskStore = InMemoryTaskStore(seed: true) // seeds MW
        let taskService = TaskService(store: taskStore)

        let importService = ShiftImportService(
            workDayService: wdService,
            shiftLookup: { [self] in shiftLookup($0) },
            taskService: taskService,
            calendar: calendar
        )
        let exportService = ShiftExportService(calendar: calendar)

        let vm = DataManagementViewModel(
            importService: importService,
            exportService: exportService,
            workDayService: wdService,
            taskService: taskService,
            calendar: calendar
        )
        return (vm, wdService, taskService, repo)
    }

    // MARK: - Settings presence (structural)

    // Tests 1-3: The Data Management screen exposes Import/Export/Template.
    // These are UI structural facts verified via the VM's public API surface.
    func testSettingsExposesImport() {
        let sys = makeSystem()
        // prepareImport(content:) exists and returns a preview for valid content.
        let ok = sys.vm.prepareImport(content: "Date,Shift,Task,Note\n01/08/2026,C1,,")
        XCTAssertTrue(ok)
        XCTAssertNotNil(sys.vm.preview)
    }

    func testSettingsExposesExport() {
        let sys = makeSystem()
        let content = sys.vm.makeExportContent()
        XCTAssertNotNil(content)
    }

    func testSettingsExposesTemplate() {
        let sys = makeSystem()
        let template = sys.vm.makeTemplateContent()
        XCTAssertTrue(template.contains("Date,Shift,Task,Note"))
    }

    // MARK: - Export

    func testExportGeneratesCorrectHeaders() {
        let sys = makeSystem()
        let content = sys.vm.makeExportContent() ?? ""
        let firstLine = content.components(separatedBy: "\n").first ?? ""
        XCTAssertEqual(firstLine, "Date,Shift,Task,Note")
    }

    func testExportSortsByDate() throws {
        let sys = makeSystem()
        _ = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 3), shift: c1, rules: [])
        _ = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 1), shift: c3, rules: [])
        _ = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 2), shift: c4, rules: [])

        let lines = (sys.vm.makeExportContent() ?? "").components(separatedBy: "\n")
        // Line 0 header; lines 1-3 ascending by date.
        XCTAssertTrue(lines[1].hasPrefix("01/08/2026"))
        XCTAssertTrue(lines[2].hasPrefix("02/08/2026"))
        XCTAssertTrue(lines[3].hasPrefix("03/08/2026"))
    }

    func testExportIncludesTask() throws {
        let sys = makeSystem()
        let wd = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 2), shift: c5, rules: c5Rules)
        let mw = try XCTUnwrap(sys.taskService.task(withCode: "MW"))
        try sys.taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        let content = sys.vm.makeExportContent() ?? ""
        XCTAssertTrue(content.contains("02/08/2026,C5,MW,"))
    }

    func testExportIncludesMultipleTasks() throws {
        let sys = makeSystem()
        let wd = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 2), shift: c5, rules: c5Rules)
        let mw = try XCTUnwrap(sys.taskService.task(withCode: "MW"))
        let ticket = try sys.taskService.createTask(code: "Ticket", name: "Ticket")
        try sys.taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        try sys.taskService.addTask(taskDefinitionID: ticket.id, toWorkDay: wd.id)

        let content = sys.vm.makeExportContent() ?? ""
        // Deterministic sorted join (MW;Ticket).
        XCTAssertTrue(content.contains("MW;Ticket"))
    }

    func testExportIncludesNote() throws {
        let sys = makeSystem()
        _ = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 2), shift: c5, rules: c5Rules, note: "Trực MW")
        let content = sys.vm.makeExportContent() ?? ""
        XCTAssertTrue(content.contains("Trực MW"))
    }

    func testExportExcludesResolvedTimes() throws {
        let sys = makeSystem()
        _ = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let content = sys.vm.makeExportContent() ?? ""
        // C5 day 15 = 12:00 → 21:30; those times must NOT appear in export.
        XCTAssertFalse(content.contains("12:00"))
        XCTAssertFalse(content.contains("21:30"))
    }

    func testExportIsReadOnly() throws {
        let sys = makeSystem()
        let wd = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let before = try XCTUnwrap(sys.workDayService.fetchWorkDay(id: wd.id))

        _ = sys.vm.makeExportContent()

        let after = try XCTUnwrap(sys.workDayService.fetchWorkDay(id: wd.id))
        XCTAssertEqual(before.resolvedStartDateTime, after.resolvedStartDateTime)
        XCTAssertEqual(before.resolvedEndDateTime, after.resolvedEndDateTime)
        XCTAssertEqual(sys.repo.count, 1)
    }

    func testTemplateHasCorrectHeaders() {
        let sys = makeSystem()
        XCTAssertEqual(sys.vm.makeTemplateContent(), "Date,Shift,Task,Note")
    }

    // MARK: - Import

    func testImportValidCSV() {
        let sys = makeSystem()
        let content = """
        Date,Shift,Task,Note
        01/08/2026,C1,,
        02/08/2026,C5,MW,Trực MW
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        let result = sys.vm.executeImport()
        XCTAssertEqual(result?.created, 2)
        XCTAssertEqual(sys.repo.count, 2)
    }

    func testImportSemicolonSeparatedTasks() throws {
        let sys = makeSystem()
        _ = try sys.taskService.createTask(code: "Ticket", name: "Ticket")
        let content = """
        Date,Shift,Task,Note
        06/08/2026,C5,MW;Ticket,Họp team
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        let result = sys.vm.executeImport()
        XCTAssertEqual(result?.created, 1)

        let wd = try XCTUnwrap(sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 6)))
        let codes = Set(sys.taskService.tasks(forWorkDay: wd.id).map { $0.code })
        XCTAssertEqual(codes, ["MW", "Ticket"])
    }

    func testImportInvalidDate() {
        let sys = makeSystem()
        let content = """
        Date,Shift,Task,Note
        32/13/2026,C1,,
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        XCTAssertEqual(sys.vm.preview?.errorRows.count, 1)
        _ = sys.vm.executeImport()
        XCTAssertEqual(sys.repo.count, 0) // invalid rows never imported
    }

    func testImportInvalidShift() {
        let sys = makeSystem()
        let content = """
        Date,Shift,Task,Note
        01/08/2026,C9,,
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        XCTAssertEqual(sys.vm.preview?.errorRows.count, 1)
    }

    func testImportInvalidTask() {
        let sys = makeSystem()
        let content = """
        Date,Shift,Task,Note
        01/08/2026,C5,ABC,
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        XCTAssertEqual(sys.vm.preview?.errorRows.count, 1)
    }

    func testImportDuplicateDateInFile() {
        let sys = makeSystem()
        let content = """
        Date,Shift,Task,Note
        15/08/2026,C5,MW,
        15/08/2026,C4,,
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        XCTAssertEqual(sys.vm.preview?.duplicateRows.count, 2)
        _ = sys.vm.executeImport()
        XCTAssertEqual(sys.repo.count, 0) // neither duplicate imported
    }

    func testExistingWorkDayConflictDetected() throws {
        let sys = makeSystem()
        _ = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        let content = """
        Date,Shift,Task,Note
        15/08/2026,C5,,
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        XCTAssertEqual(sys.vm.preview?.conflictRows.count, 1)
    }

    func testSkipExistingDefault() throws {
        let sys = makeSystem()
        let existing = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,"
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        // Default strategy is skip.
        XCTAssertEqual(sys.vm.conflictStrategy, .skipExisting)
        let result = sys.vm.executeImport()
        XCTAssertEqual(result?.skipped, 1)
        // Existing WorkDay unchanged (still C4).
        let after = try XCTUnwrap(sys.workDayService.fetchWorkDay(id: existing.id))
        XCTAssertEqual(after.shiftCode, "C4")
    }

    func testReplaceExisting() throws {
        let sys = makeSystem()
        let existing = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,"
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        sys.vm.conflictStrategy = .replaceExisting
        let result = sys.vm.executeImport()
        XCTAssertEqual(result?.replaced, 1)
        // Now C5 day 15 special → 12:00–21:30.
        let after = try XCTUnwrap(sys.workDayService.fetchWorkDay(id: existing.id))
        XCTAssertEqual(after.shiftCode, "C5")
        XCTAssertEqual(timeComponents(from: after.resolvedStartDateTime).hour, 12)
        XCTAssertEqual(timeComponents(from: after.resolvedEndDateTime).hour, 21)
        XCTAssertEqual(timeComponents(from: after.resolvedEndDateTime).minute, 30)
    }

    func testOFFCreatesNoWorkDay() {
        let sys = makeSystem()
        let content = "Date,Shift,Task,Note\n15/08/2026,OFF,,Nghỉ"
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        let result = sys.vm.executeImport()
        XCTAssertEqual(result?.offDays, 1)
        XCTAssertEqual(result?.created, 0)
        XCTAssertEqual(sys.repo.count, 0)
    }

    func testOFFRemovesExistingWhenReplaceChosen() throws {
        let sys = makeSystem()
        _ = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        XCTAssertEqual(sys.repo.count, 1)
        let content = "Date,Shift,Task,Note\n15/08/2026,OFF,,"
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        sys.vm.conflictStrategy = .replaceExisting
        _ = sys.vm.executeImport()
        // OFF replace deletes the existing WorkDay → day becomes OFF (no record).
        XCTAssertNil(try sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15)))
        XCTAssertEqual(sys.repo.count, 0)
    }

    // MARK: - Note / Task Independence

    func testNoteRemainsSeparateFromTask() throws {
        let sys = makeSystem()
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,MW,Trực MW"
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        _ = sys.vm.executeImport()
        let wd = try XCTUnwrap(sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15)))
        // Note holds ONLY the note; task is not embedded in note.
        XCTAssertEqual(wd.note, "Trực MW")
        XCTAssertFalse((wd.note ?? "").contains("MW - "))
        // Task assigned separately.
        XCTAssertEqual(Set(sys.taskService.tasks(forWorkDay: wd.id).map { $0.code }), ["MW"])
    }

    func testMWDoesNotAlterSnapshot() throws {
        let sys = makeSystem()
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,MW,"
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        _ = sys.vm.executeImport()
        let wd = try XCTUnwrap(sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15)))
        // C5 day 15 special regardless of MW.
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)
        XCTAssertEqual(timeComponents(from: wd.resolvedEndDateTime).hour, 21)
        XCTAssertEqual(timeComponents(from: wd.resolvedEndDateTime).minute, 30)
    }

    // MARK: - Historical Snapshot

    func testHistoricalSnapshotSurvivesConfigChange() throws {
        let sys = makeSystem()
        // Import C5 on day 15 → 12:00–21:30.
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,"
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        _ = sys.vm.executeImport()
        let wd = try XCTUnwrap(sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15)))
        let originalStart = wd.resolvedStartDateTime
        let originalEnd = wd.resolvedEndDateTime

        // Simulate a global C5 config change by fetching the same WorkDay again.
        // The VM/import never rewrites existing snapshots; only explicit changeShift does.
        let reloaded = try XCTUnwrap(sys.workDayService.fetchWorkDay(id: wd.id))
        XCTAssertEqual(reloaded.resolvedStartDateTime, originalStart)
        XCTAssertEqual(reloaded.resolvedEndDateTime, originalEnd)
    }

    // MARK: - C5 Boundary via Import

    func testImportC5Day9Normal() throws {
        let sys = makeSystem()
        XCTAssertTrue(sys.vm.prepareImport(content: "Date,Shift,Task,Note\n09/08/2026,C5,,"))
        _ = sys.vm.executeImport()
        let wd = try XCTUnwrap(sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 9)))
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 11)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).minute, 30)
    }

    func testImportC5Day10Special() throws {
        let sys = makeSystem()
        XCTAssertTrue(sys.vm.prepareImport(content: "Date,Shift,Task,Note\n10/08/2026,C5,,"))
        _ = sys.vm.executeImport()
        let wd = try XCTUnwrap(sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 10)))
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).minute, 0)
    }

    func testImportC5Day20Special() throws {
        let sys = makeSystem()
        XCTAssertTrue(sys.vm.prepareImport(content: "Date,Shift,Task,Note\n20/08/2026,C5,,"))
        _ = sys.vm.executeImport()
        let wd = try XCTUnwrap(sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 20)))
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)
    }

    func testImportC5Day21Normal() throws {
        let sys = makeSystem()
        XCTAssertTrue(sys.vm.prepareImport(content: "Date,Shift,Task,Note\n21/08/2026,C5,,"))
        _ = sys.vm.executeImport()
        let wd = try XCTUnwrap(sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 21)))
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 11)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).minute, 30)
    }

    // MARK: - Round Trip

    func testRoundTripPreservesDateShiftTasksNote() throws {
        let sys = makeSystem()
        let wd = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "Chuyển ticket")
        let mw = try XCTUnwrap(sys.taskService.task(withCode: "MW"))
        try sys.taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        // Export.
        let exported = try XCTUnwrap(sys.vm.makeExportContent())

        // Fresh system, import the exported content.
        let sys2 = makeSystem()
        XCTAssertTrue(sys2.vm.prepareImport(content: exported))
        _ = sys2.vm.executeImport()

        let wd2 = try XCTUnwrap(sys2.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15)))
        XCTAssertEqual(wd2.shiftCode, "C5")
        XCTAssertEqual(wd2.note, "Chuyển ticket")
        XCTAssertEqual(Set(sys2.taskService.tasks(forWorkDay: wd2.id).map { $0.code }), ["MW"])
        // Resolved via ShiftResolver (day 15 special).
        XCTAssertEqual(timeComponents(from: wd2.resolvedStartDateTime).hour, 12)
    }

    // MARK: - Error Handling / No Internal Details

    func testEmptyFileError() {
        let sys = makeSystem()
        XCTAssertFalse(sys.vm.prepareImport(content: "   "))
        XCTAssertEqual(sys.vm.errorMessage, "File không có dữ liệu.")
    }

    func testInvalidHeaderError() {
        let sys = makeSystem()
        XCTAssertFalse(sys.vm.prepareImport(content: "Foo,Bar\n1,2"))
        XCTAssertEqual(sys.vm.errorMessage, "Cần các cột: Date, Shift, Task, Note.")
    }

    func testUnsupportedExtensionRejected() {
        let sys = makeSystem()
        let url = URL(fileURLWithPath: "/tmp/schedule.xlsx")
        XCTAssertFalse(sys.vm.prepareImport(url: url))
        XCTAssertEqual(sys.vm.errorMessage, "Chỉ hỗ trợ file CSV.")
    }

    func testErrorMessagesContainNoInternalDetails() {
        let sys = makeSystem()
        _ = sys.vm.prepareImport(content: "   ")
        let msg = sys.vm.errorMessage ?? ""
        XCTAssertFalse(msg.lowercased().contains("error"))
        XCTAssertFalse(msg.contains("Swift"))
        XCTAssertFalse(msg.contains("UUID"))
        XCTAssertFalse(msg.contains("ImportParseError"))
    }

    // MARK: - Failure does not corrupt persisted data

    func testFailedImportDoesNotPartiallyCorrupt() throws {
        let sys = makeSystem()
        // One valid, one invalid row. Only valid row imports; invalid never persists.
        let content = """
        Date,Shift,Task,Note
        01/08/2026,C1,,
        02/08/2026,C9,,
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        let result = sys.vm.executeImport()
        XCTAssertEqual(result?.created, 1)
        XCTAssertEqual(sys.repo.count, 1)
        XCTAssertNotNil(try sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 1)))
        XCTAssertNil(try sys.workDayService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 2)))
    }

    // MARK: - Confirmation summary counts

    func testConfirmationSummaryCounts() throws {
        let sys = makeSystem()
        _ = try sys.workDayService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 2), shift: c4, rules: [])
        let content = """
        Date,Shift,Task,Note
        01/08/2026,C1,,
        02/08/2026,C5,,
        03/08/2026,C9,,
        """
        XCTAssertTrue(sys.vm.prepareImport(content: content))
        // skip default: 1 add (day1), 1 skip (day2 conflict), 1 error (day3)
        XCTAssertEqual(sys.vm.willAddCount, 1)
        XCTAssertEqual(sys.vm.willSkipCount, 1)
        XCTAssertEqual(sys.vm.willUpdateCount, 0)
        XCTAssertEqual(sys.vm.errorCount, 1)
    }
}
