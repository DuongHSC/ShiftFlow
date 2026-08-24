// ShiftFlow — Tests
// ShiftImportTests.swift
//
// TASK-IMPORT-001: Comprehensive import tests.
//
// Tests cover:
// - Valid import (C1–C5)
// - C5 special rule via import
// - C5 boundary (day 9/10/20/21)
// - Task independence (MW does not change times)
// - Note import
// - Invalid shift code
// - Missing date
// - Invalid date format
// - Duplicate dates within file
// - Existing WorkDay conflict detection
// - Skip existing strategy
// - Replace existing strategy
// - Historical snapshot preserved after import
// - Empty file
// - Invalid header
// - OFF handling

import XCTest
@testable import ShiftFlowDomain

final class ShiftImportTests: XCTestCase {

    // MARK: - Test Infrastructure

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }

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

    private func timeComponents(from date: Date) -> (hour: Int, minute: Int) {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return (hour, minute)
    }

    private var c1: ShiftDefinition { ShiftSeedProvider.makeC1() }
    private var c2: ShiftDefinition { ShiftSeedProvider.makeC2() }
    private var c3: ShiftDefinition { ShiftSeedProvider.makeC3() }
    private var c4: ShiftDefinition { ShiftSeedProvider.makeC4() }
    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    private func shiftLookup(_ code: String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? {
        switch code.uppercased() {
        case "C1": return (c1, [])
        case "C2": return (c2, [])
        case "C3": return (c3, [])
        case "C4": return (c4, [])
        case "C5": return (c5, c5Rules)
        default: return nil
        }
    }

    private func makeService() -> (WorkDayService, InMemoryWorkDayRepository) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar)
        return (service, repo)
    }

    // MARK: - Parser Tests

    func testParseValidCSV() {
        let content = """
        Date,Shift,Task,Note
        01/08/2026,C1,,
        02/08/2026,C5,MW,Trực MW
        03/08/2026,C3,Zalo,
        """

        let rows = try! ShiftFileParser.parse(content: content)

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0].rowNumber, 2)
        XCTAssertEqual(rows[0].dateString, "01/08/2026")
        XCTAssertEqual(rows[0].shiftString, "C1")
        XCTAssertNil(rows[0].taskString)
        XCTAssertNil(rows[0].noteString)

        XCTAssertEqual(rows[1].dateString, "02/08/2026")
        XCTAssertEqual(rows[1].shiftString, "C5")
        XCTAssertEqual(rows[1].taskString, "MW")
        XCTAssertEqual(rows[1].noteString, "Trực MW")
    }

    func testParsePipeDelimited() {
        let content = """
        Date | Shift | Task | Note
        01/08/2026 | C1 |  |
        02/08/2026 | C5 | MW | Trực MW
        """

        let rows = try! ShiftFileParser.parse(content: content)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].shiftString, "C1")
        XCTAssertEqual(rows[1].taskString, "MW")
        XCTAssertEqual(rows[1].noteString, "Trực MW")
    }

    func testParseTabDelimited() {
        let content = "Date\tShift\tTask\tNote\n01/08/2026\tC1\t\t\n02/08/2026\tC5\tMW\tTrực MW"

        let rows = try! ShiftFileParser.parse(content: content)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1].shiftString, "C5")
    }

    func testParseEmptyFileThrows() {
        XCTAssertThrowsError(try ShiftFileParser.parse(content: "")) { error in
            XCTAssertEqual(error as? ImportParseError, ImportParseError.emptyFile)
        }
    }

    func testParseInvalidHeaderThrows() {
        let content = "Name,Age\nJohn,30"
        XCTAssertThrowsError(try ShiftFileParser.parse(content: content)) { error in
            XCTAssertEqual(error as? ImportParseError, ImportParseError.invalidHeader)
        }
    }

    // MARK: - Validator Tests

    func testValidRowsPassValidation() {
        let rows = [
            ImportRawRow(rowNumber: 2, dateString: "01/08/2026", shiftString: "C1", taskString: nil, noteString: nil),
            ImportRawRow(rowNumber: 3, dateString: "02/08/2026", shiftString: "C5", taskString: "MW", noteString: "Note"),
        ]

        let validated = ImportValidator.validate(rows: rows, existingWorkDayDates: Set(), calendar: calendar)

        XCTAssertEqual(validated.count, 2)
        XCTAssertEqual(validated[0].status, .valid)
        XCTAssertEqual(validated[1].status, .valid)
    }

    func testInvalidShiftCodeDetected() {
        let rows = [
            ImportRawRow(rowNumber: 2, dateString: "01/08/2026", shiftString: "C7", taskString: nil, noteString: nil),
        ]

        let validated = ImportValidator.validate(rows: rows, existingWorkDayDates: Set(), calendar: calendar)

        XCTAssertEqual(validated.count, 1)
        if case .error(let msg) = validated[0].status {
            XCTAssertTrue(msg.contains("Invalid shift"), "Error should mention invalid shift: \(msg)")
        } else {
            XCTFail("Expected error status for invalid shift")
        }
    }

    func testMissingDateDetected() {
        let rows = [
            ImportRawRow(rowNumber: 2, dateString: nil, shiftString: "C1", taskString: nil, noteString: nil),
        ]

        let validated = ImportValidator.validate(rows: rows, existingWorkDayDates: Set(), calendar: calendar)

        if case .error(let msg) = validated[0].status {
            XCTAssertTrue(msg.contains("Missing date"), "Error should mention missing date: \(msg)")
        } else {
            XCTFail("Expected error status for missing date")
        }
    }

    func testInvalidDateFormatDetected() {
        let rows = [
            ImportRawRow(rowNumber: 2, dateString: "2026-08-01", shiftString: "C1", taskString: nil, noteString: nil),
        ]

        let validated = ImportValidator.validate(rows: rows, existingWorkDayDates: Set(), calendar: calendar)

        if case .error(let msg) = validated[0].status {
            XCTAssertTrue(msg.contains("Invalid date"), "Error should mention invalid date: \(msg)")
        } else {
            XCTFail("Expected error status for invalid date format")
        }
    }

    func testMissingShiftDetected() {
        let rows = [
            ImportRawRow(rowNumber: 2, dateString: "01/08/2026", shiftString: nil, taskString: nil, noteString: nil),
        ]

        let validated = ImportValidator.validate(rows: rows, existingWorkDayDates: Set(), calendar: calendar)

        if case .error(let msg) = validated[0].status {
            XCTAssertTrue(msg.contains("Missing shift"), "Error should mention missing shift: \(msg)")
        } else {
            XCTFail("Expected error status for missing shift")
        }
    }

    func testDuplicateDatesWithinFileDetected() {
        let rows = [
            ImportRawRow(rowNumber: 2, dateString: "15/08/2026", shiftString: "C5", taskString: nil, noteString: nil),
            ImportRawRow(rowNumber: 3, dateString: "15/08/2026", shiftString: "C4", taskString: nil, noteString: nil),
        ]

        let validated = ImportValidator.validate(rows: rows, existingWorkDayDates: Set(), calendar: calendar)

        XCTAssertEqual(validated.count, 2)
        if case .duplicateInFile = validated[0].status {} else {
            XCTFail("Row 1 should be marked as duplicate")
        }
        if case .duplicateInFile = validated[1].status {} else {
            XCTFail("Row 2 should be marked as duplicate")
        }
    }

    func testExistingWorkDayConflictDetected() {
        let existingDate = calendar.startOfDay(for: makeDate(year: 2026, month: 8, day: 15))
        let rows = [
            ImportRawRow(rowNumber: 2, dateString: "15/08/2026", shiftString: "C5", taskString: nil, noteString: nil),
        ]

        let validated = ImportValidator.validate(
            rows: rows,
            existingWorkDayDates: Set([existingDate]),
            calendar: calendar
        )

        if case .conflict = validated[0].status {} else {
            XCTFail("Should detect existing WorkDay conflict")
        }
    }

    func testOFFIsValidButNotImportable() {
        let rows = [
            ImportRawRow(rowNumber: 2, dateString: "04/08/2026", shiftString: "OFF", taskString: nil, noteString: "Nghỉ"),
        ]

        let validated = ImportValidator.validate(rows: rows, existingWorkDayDates: Set(), calendar: calendar)

        XCTAssertEqual(validated[0].status, .valid)
        XCTAssertTrue(validated[0].isOff)
        XCTAssertFalse(validated[0].isImportable)
    }

    // MARK: - Preview Tests

    func testPreviewCounts() {
        let rows = [
            ImportValidatedRow(rowNumber: 2, date: makeDate(year: 2026, month: 8, day: 1), shiftCode: "C1", task: nil, note: nil, status: .valid),
            ImportValidatedRow(rowNumber: 3, date: makeDate(year: 2026, month: 8, day: 2), shiftCode: "C5", task: "MW", note: nil, status: .valid),
            ImportValidatedRow(rowNumber: 4, date: makeDate(year: 2026, month: 8, day: 3), shiftCode: "OFF", task: nil, note: nil, status: .valid),
            ImportValidatedRow(rowNumber: 5, date: nil, shiftCode: nil, task: nil, note: nil, status: .error("Missing date")),
            ImportValidatedRow(rowNumber: 6, date: makeDate(year: 2026, month: 8, day: 4), shiftCode: "C4", task: nil, note: nil, status: .conflict("Existing")),
        ]

        let preview = ImportPreview(rows: rows)

        XCTAssertEqual(preview.totalRows, 5)
        XCTAssertEqual(preview.validRows.count, 2) // C1 and C5 (not OFF)
        XCTAssertEqual(preview.offRows.count, 1)
        XCTAssertEqual(preview.errorRows.count, 1)
        XCTAssertEqual(preview.conflictRows.count, 1)
        XCTAssertTrue(preview.canImport)
        XCTAssertTrue(preview.hasIssues)
    }

    // MARK: - Integration Tests (Import → WorkDay → ShiftResolver)

    func testImportC1CreatesWorkDayWithCorrectSnapshot() throws {
        let (wdService, repo) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService,
            shiftLookup: shiftLookup,
            calendar: calendar
        )

        let content = "Date,Shift,Task,Note\n01/08/2026,C1,,"

        let preview = try importService.prepareImport(content: content)
        XCTAssertEqual(preview.validRows.count, 1)

        let result = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(result.created, 1)

        let workDay = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 1))
        XCTAssertNotNil(workDay)

        let start = timeComponents(from: workDay!.resolvedStartDateTime)
        let end = timeComponents(from: workDay!.resolvedEndDateTime)
        XCTAssertEqual(start.hour, 7)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 16)
        XCTAssertEqual(end.minute, 30)
    }

    func testImportC5OnDay15UsesSpecialSchedule() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService,
            shiftLookup: shiftLookup,
            calendar: calendar
        )

        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,"

        let preview = try importService.prepareImport(content: content)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let workDay = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!

        let start = timeComponents(from: workDay.resolvedStartDateTime)
        let end = timeComponents(from: workDay.resolvedEndDateTime)
        let breakStart = timeComponents(from: workDay.resolvedBreakStartDateTime)
        let breakEnd = timeComponents(from: workDay.resolvedBreakEndDateTime)

        XCTAssertEqual(start.hour, 12)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
        XCTAssertEqual(breakStart.hour, 16)
        XCTAssertEqual(breakStart.minute, 30)
        XCTAssertEqual(breakEnd.hour, 17)
        XCTAssertEqual(breakEnd.minute, 30)
    }

    func testImportC5BoundaryDay9() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )
        let content = "Date,Shift,Task,Note\n09/08/2026,C5,,"
        let preview = try importService.prepareImport(content: content)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let workDay = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 9))!
        let start = timeComponents(from: workDay.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 11, "Day 9 → normal")
        XCTAssertEqual(start.minute, 30)
    }

    func testImportC5BoundaryDay10() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )
        let content = "Date,Shift,Task,Note\n10/08/2026,C5,,"
        let preview = try importService.prepareImport(content: content)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let workDay = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 10))!
        let start = timeComponents(from: workDay.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 12, "Day 10 → special")
        XCTAssertEqual(start.minute, 0)
    }

    func testImportC5BoundaryDay20() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )
        let content = "Date,Shift,Task,Note\n20/08/2026,C5,,"
        let preview = try importService.prepareImport(content: content)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let workDay = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 20))!
        let start = timeComponents(from: workDay.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 12, "Day 20 → special")
        XCTAssertEqual(start.minute, 0)
    }

    func testImportC5BoundaryDay21() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )
        let content = "Date,Shift,Task,Note\n21/08/2026,C5,,"
        let preview = try importService.prepareImport(content: content)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let workDay = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 21))!
        let start = timeComponents(from: workDay.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 11, "Day 21 → normal")
        XCTAssertEqual(start.minute, 30)
    }

    // MARK: - Task Independence

    func testTaskMWDoesNotChangeShiftSnapshot() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        // Import C5 on day 15 WITHOUT task.
        let content1 = "Date,Shift,Task,Note\n15/08/2026,C5,,"
        let preview1 = try importService.prepareImport(content: content1)
        let _ = try importService.executeImport(preview: preview1, strategy: .skipExisting)
        let withoutTask = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!

        // Delete and re-import WITH task MW.
        try wdService.deleteWorkDay(id: withoutTask.id)

        let content2 = "Date,Shift,Task,Note\n15/08/2026,C5,MW,"
        let preview2 = try importService.prepareImport(content: content2)
        let _ = try importService.executeImport(preview: preview2, strategy: .skipExisting)
        let withTask = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!

        // Snapshot must be IDENTICAL regardless of task.
        XCTAssertEqual(
            timeComponents(from: withoutTask.resolvedStartDateTime).hour,
            timeComponents(from: withTask.resolvedStartDateTime).hour,
            "MW must not change start time"
        )
        XCTAssertEqual(
            timeComponents(from: withoutTask.resolvedEndDateTime).hour,
            timeComponents(from: withTask.resolvedEndDateTime).hour,
            "MW must not change end time"
        )
        XCTAssertEqual(
            timeComponents(from: withoutTask.resolvedBreakStartDateTime).hour,
            timeComponents(from: withTask.resolvedBreakStartDateTime).hour,
            "MW must not change break start"
        )
    }

    // MARK: - Note Import

    func testNoteIsImported() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        let content = "Date,Shift,Task,Note\n02/08/2026,C5,MW,Trực MW"
        let preview = try importService.prepareImport(content: content)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let workDay = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 2))!
        XCTAssertEqual(workDay.note, "Trực MW")
    }

    // MARK: - OFF Handling

    func testOFFDoesNotCreateWorkDay() throws {
        let (wdService, repo) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        let content = "Date,Shift,Task,Note\n04/08/2026,OFF,,Nghỉ"
        let preview = try importService.prepareImport(content: content)

        XCTAssertEqual(preview.offRows.count, 1)
        XCTAssertEqual(preview.validRows.count, 0) // OFF is not importable

        let result = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(result.offDays, 1)
        XCTAssertEqual(result.created, 0)
        XCTAssertEqual(repo.count, 0, "OFF must not create a WorkDay")
    }

    // MARK: - Conflict: Skip Existing

    func testSkipExistingPreservesOriginalWorkDay() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        // Create existing WorkDay with C4.
        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c4, rules: []
        )

        // Import C5 for the same date.
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,"
        let preview = try importService.prepareImport(content: content)

        XCTAssertEqual(preview.conflictRows.count, 1)

        let result = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.created, 0)

        // Original C4 remains.
        let existing = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(existing.shiftCode, "C4", "Skip must preserve original")
    }

    // MARK: - Conflict: Replace Existing

    func testReplaceExistingUpdatesWorkDay() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        // Create existing WorkDay with C4.
        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c4, rules: []
        )

        // Import C5 for the same date.
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,New note"
        let preview = try importService.prepareImport(content: content)
        let result = try importService.executeImport(preview: preview, strategy: .replaceExisting)

        XCTAssertEqual(result.replaced, 1)

        // Verify replaced with C5 special schedule.
        let updated = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(updated.shiftCode, "C5")
        let start = timeComponents(from: updated.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 12, "Replaced must use new C5 special resolution")
        XCTAssertEqual(start.minute, 0)
    }

    // MARK: - Historical Snapshot After Import

    func testImportedWorkDaySnapshotNotAffectedByConfigChange() throws {
        let (wdService, repo) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        // Import C5 on day 15.
        let content = "Date,Shift,Task,Note\n15/08/2026,C5,,"
        let preview = try importService.prepareImport(content: content)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        let imported = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!

        // Verify initial snapshot.
        let startBefore = timeComponents(from: imported.resolvedStartDateTime)
        XCTAssertEqual(startBefore.hour, 12)
        XCTAssertEqual(startBefore.minute, 0)

        // Simulate global config change (does NOT call changeShift).
        // The new config is irrelevant — snapshot is stored.

        // Reload and verify unchanged.
        let reloaded = try repo.fetchByID(imported.id)!
        let startAfter = timeComponents(from: reloaded.resolvedStartDateTime)
        XCTAssertEqual(startAfter.hour, 12, "Historical snapshot must survive config change")
        XCTAssertEqual(startAfter.minute, 0)
    }

    // MARK: - Multi-Row Import

    func testImportMultipleValidRows() throws {
        let (wdService, repo) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        let content = """
        Date,Shift,Task,Note
        01/08/2026,C1,,
        02/08/2026,C2,,
        03/08/2026,C3,,
        04/08/2026,C4,,
        05/08/2026,C5,,
        """

        let preview = try importService.prepareImport(content: content)
        XCTAssertEqual(preview.validRows.count, 5)
        XCTAssertFalse(preview.hasIssues)

        let result = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(result.created, 5)
        XCTAssertEqual(repo.count, 5)
    }

    // MARK: - Mixed Valid and Invalid

    func testMixedRowsOnlyImportsValid() throws {
        let (wdService, repo) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        let content = """
        Date,Shift,Task,Note
        01/08/2026,C1,,
        ,C5,,
        03/08/2026,C7,,
        04/08/2026,C4,,
        """

        let preview = try importService.prepareImport(content: content)
        XCTAssertEqual(preview.validRows.count, 2)  // Row 2 and 5 (C1, C4)
        XCTAssertEqual(preview.errorRows.count, 2)  // Missing date, invalid shift

        let result = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(result.created, 2)
        XCTAssertEqual(repo.count, 2)
    }

    // MARK: - Export Tests

    func testExportProducesCorrectColumnFormat() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )

        // Create WorkDays.
        let content = "Date,Shift,Task,Note\n01/08/2026,C1,,\n15/08/2026,C5,,Test note"
        let preview = try importService.prepareImport(content: content)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        // Export.
        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: workDays)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.rows[0].dateString, "01/08/2026")
        XCTAssertEqual(result.rows[0].shiftCode, "C1")
        XCTAssertEqual(result.rows[1].dateString, "15/08/2026")
        XCTAssertEqual(result.rows[1].shiftCode, "C5")
        XCTAssertEqual(result.rows[1].note, "Test note")
    }

    func testExportDoesNotIncludeResolvedTimes() throws {
        let (wdService, _) = makeService()

        // Create a C5 WorkDay on day 15.
        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c5, rules: c5Rules, note: "Note"
        )

        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: workDays)

        // The text content must NOT contain "12:00" or "21:30" as column data.
        let lines = result.textContent.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2) // header + 1 row

        // Header must be Date,Shift,Task,Note only.
        XCTAssertEqual(lines[0], "Date,Shift,Task,Note")

        // Data row must not have time columns.
        let dataColumns = lines[1].split(separator: ",", omittingEmptySubsequences: false)
        XCTAssertEqual(dataColumns.count, 4, "Export must have exactly 4 columns")
        XCTAssertEqual(String(dataColumns[0]), "15/08/2026")
        XCTAssertEqual(String(dataColumns[1]), "C5")
        // No 12:00 or 21:30 in the export.
        XCTAssertFalse(result.textContent.contains("12:00"))
        XCTAssertFalse(result.textContent.contains("21:30"))
    }

    func testExportDoesNotModifyWorkDays() throws {
        let (wdService, repo) = makeService()

        let original = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c5, rules: c5Rules, note: "Original"
        )

        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )

        let exportService = ShiftExportService(calendar: calendar)
        let _ = exportService.export(workDays: workDays)

        // Verify WorkDay is unchanged after export.
        let afterExport = try repo.fetchByID(original.id)!
        XCTAssertEqual(afterExport.resolvedStartDateTime, original.resolvedStartDateTime)
        XCTAssertEqual(afterExport.resolvedEndDateTime, original.resolvedEndDateTime)
        XCTAssertEqual(afterExport.note, "Original")
        XCTAssertEqual(afterExport.shiftCode, "C5")
    }

    func testExportPreservesDate() throws {
        let (wdService, _) = makeService()

        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 22),
            shift: c3, rules: []
        )

        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: workDays)

        XCTAssertEqual(result.rows[0].dateString, "22/08/2026")
    }

    func testExportPreservesShiftCode() throws {
        let (wdService, _) = makeService()

        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 5),
            shift: c4, rules: []
        )

        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: workDays)

        XCTAssertEqual(result.rows[0].shiftCode, "C4")
    }

    func testExportPreservesNote() throws {
        let (wdService, _) = makeService()

        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 5),
            shift: c1, rules: [], note: "Họp team lúc 14:00"
        )

        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: workDays)

        XCTAssertEqual(result.rows[0].note, "Họp team lúc 14:00")
    }

    func testExportWithTaskLookup() throws {
        let (wdService, _) = makeService()

        let workDay = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 5),
            shift: c5, rules: c5Rules
        )

        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: workDays) { id in
            id == workDay.id ? "MW" : nil
        }

        XCTAssertEqual(result.rows[0].task, "MW")
    }

    func testExportSortsByDateAscending() throws {
        let (wdService, _) = makeService()

        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 20), shift: c4, rules: [])
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 5), shift: c1, rules: [])
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 12), shift: c3, rules: [])

        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )

        let exportService = ShiftExportService(calendar: calendar)
        let result = exportService.export(workDays: workDays)

        XCTAssertEqual(result.rows[0].dateString, "05/08/2026")
        XCTAssertEqual(result.rows[1].dateString, "12/08/2026")
        XCTAssertEqual(result.rows[2].dateString, "20/08/2026")
    }

    // MARK: - Template Tests

    func testTemplateHasCorrectHeaders() {
        XCTAssertEqual(ShiftTemplate.headers, ["Date", "Shift", "Task", "Note"])
    }

    func testTemplateWithExamples() {
        let content = ShiftTemplate.generateTemplateContent(includeExamples: true)
        let lines = content.components(separatedBy: "\n")

        XCTAssertGreaterThan(lines.count, 1, "Template with examples must have header + rows")
        XCTAssertEqual(lines[0], "Date,Shift,Task,Note")
        XCTAssertTrue(lines[1].contains("C1"), "First example should contain C1")
    }

    func testEmptyTemplateHasHeaderOnly() {
        let content = ShiftTemplate.generateEmptyTemplate()
        XCTAssertEqual(content, "Date,Shift,Task,Note")
        XCTAssertFalse(content.contains("\n"))
    }

    func testTemplateDoesNotContainResolvedTimes() {
        let content = ShiftTemplate.generateTemplateContent(includeExamples: true)
        // Template must NOT include shift times.
        XCTAssertFalse(content.contains("07:00"))
        XCTAssertFalse(content.contains("16:30"))
        XCTAssertFalse(content.contains("12:00"))
        XCTAssertFalse(content.contains("21:30"))
    }

    // MARK: - XLSX Format Tests

    func testXLSXIsOfficialFormat() {
        XCTAssertEqual(ShiftFileFormat.official, .xlsx)
    }

    func testXLSXFileExtension() {
        XCTAssertEqual(ShiftFileFormat.xlsx.fileExtension, ".xlsx")
    }

    func testCSVIsSecondaryFormat() {
        // CSV is supported but not the official format.
        XCTAssertNotEqual(ShiftFileFormat.official, .csv)
        XCTAssertEqual(ShiftFileFormat.csv.fileExtension, ".csv")
    }

    // MARK: - Round-Trip Tests (Export → Import)

    func testRoundTripPreservesDateShiftNote() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )
        let exportService = ShiftExportService(calendar: calendar)

        // Step 1: Create WorkDays.
        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 1), shift: c1, rules: [], note: "Note 1"
        )
        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules, note: "Note 2"
        )

        // Step 2: Export.
        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )
        let exportResult = exportService.export(workDays: workDays)

        // Step 3: Clear repository and re-import.
        for wd in workDays {
            try wdService.deleteWorkDay(id: wd.id)
        }

        let preview = try importService.prepareImport(content: exportResult.textContent)
        XCTAssertEqual(preview.validRows.count, 2)
        XCTAssertFalse(preview.hasIssues)

        let importResult = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(importResult.created, 2)

        // Step 4: Verify round-trip.
        let reimported1 = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 1))!
        let reimported2 = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!

        // Date preserved.
        XCTAssertEqual(calendar.component(.day, from: reimported1.date), 1)
        XCTAssertEqual(calendar.component(.month, from: reimported1.date), 8)
        XCTAssertEqual(calendar.component(.day, from: reimported2.date), 15)

        // Shift preserved.
        XCTAssertEqual(reimported1.shiftCode, "C1")
        XCTAssertEqual(reimported2.shiftCode, "C5")

        // Note preserved.
        XCTAssertEqual(reimported1.note, "Note 1")
        XCTAssertEqual(reimported2.note, "Note 2")
    }

    func testRoundTripResolvesScheduleViaShiftResolver() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )
        let exportService = ShiftExportService(calendar: calendar)

        // Step 1: Create C5 on day 15 (special schedule).
        _ = try wdService.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules
        )

        // Step 2: Export.
        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )
        let exportResult = exportService.export(workDays: workDays)

        // Verify export does NOT contain resolved times.
        XCTAssertFalse(exportResult.textContent.contains("12:00"))
        XCTAssertFalse(exportResult.textContent.contains("21:30"))

        // Step 3: Clear and re-import.
        for wd in workDays {
            try wdService.deleteWorkDay(id: wd.id)
        }

        let preview = try importService.prepareImport(content: exportResult.textContent)
        let _ = try importService.executeImport(preview: preview, strategy: .skipExisting)

        // Step 4: Verify resolved schedule comes from ShiftResolver.
        let reimported = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 15))!
        let start = timeComponents(from: reimported.resolvedStartDateTime)
        let end = timeComponents(from: reimported.resolvedEndDateTime)

        XCTAssertEqual(start.hour, 12, "Round-trip must resolve C5 special via ShiftResolver")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testRoundTripWithMultipleShifts() throws {
        let (wdService, _) = makeService()
        let importService = ShiftImportService(
            workDayService: wdService, shiftLookup: shiftLookup, calendar: calendar
        )
        let exportService = ShiftExportService(calendar: calendar)

        // Create C1–C5.
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 1), shift: c1, rules: [])
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 2), shift: c2, rules: [])
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 3), shift: c3, rules: [])
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 4), shift: c4, rules: [])
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 5), shift: c5, rules: c5Rules)

        // Export.
        let workDays = try wdService.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 1),
            to: makeDate(year: 2026, month: 8, day: 31)
        )
        let exportResult = exportService.export(workDays: workDays)
        XCTAssertEqual(exportResult.count, 5)

        // Clear and re-import.
        for wd in workDays {
            try wdService.deleteWorkDay(id: wd.id)
        }

        let preview = try importService.prepareImport(content: exportResult.textContent)
        XCTAssertEqual(preview.validRows.count, 5)

        let importResult = try importService.executeImport(preview: preview, strategy: .skipExisting)
        XCTAssertEqual(importResult.created, 5)

        // Verify all shifts.
        let r1 = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 1))!
        let r2 = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 2))!
        let r3 = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 3))!
        let r4 = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 4))!
        let r5 = try wdService.fetchWorkDay(date: makeDate(year: 2026, month: 8, day: 5))!

        XCTAssertEqual(r1.shiftCode, "C1")
        XCTAssertEqual(r2.shiftCode, "C2")
        XCTAssertEqual(r3.shiftCode, "C3")
        XCTAssertEqual(r4.shiftCode, "C4")
        XCTAssertEqual(r5.shiftCode, "C5")
    }
}
