// ShiftFlow — Tests
// CalendarViewModelTests.swift
//
// TASK-CALENDAR-001: Calendar ViewModel and integration tests.
//
// Tests cover:
// - Month grid correct weekday/date mapping
// - Month boundaries
// - Week view correct 7-day range
// - 3 Days correct range and navigation
// - Today view: current date, WorkDay, next shift
// - C5 boundary display (day 9/10/20/21)
// - OFF state (no persistent ShiftDefinition)
// - Task independence (MW does not change times)
// - Note indicator
// - Delete WorkDay
// - Duplicate date prevention
// - Accessibility label content
// - Navigation (previous/next/today)
//
// TASK-XCODE-FIX-001 (XP-01): This file exercises the app-layer CalendarViewModel
// (Application/ViewModels), so it imports the app module in addition to the domain
// module. It is compiled by the app-hosted `ShiftFlowTests` Xcode target, not the
// standalone `ShiftFlowDomain` SPM test target.

import XCTest
@testable import ShiftFlowDomain
@testable import ShiftFlow

final class CalendarViewModelTests: XCTestCase {

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
        (calendar.component(.hour, from: date), calendar.component(.minute, from: date))
    }

    private var c1: ShiftDefinition { ShiftSeedProvider.makeC1() }
    private var c4: ShiftDefinition { ShiftSeedProvider.makeC4() }
    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    private func makeService() -> (WorkDayService, InMemoryWorkDayRepository) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar)
        return (service, repo)
    }

    // MARK: - Month Grid Tests

    func testMonthGridContains42Dates() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 1)

        let grid = vm.monthGridDates()
        XCTAssertEqual(grid.count, 42, "Month grid must have 6 weeks × 7 days = 42 cells")
    }

    func testMonthGridStartsOnMonday() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 1)

        let grid = vm.monthGridDates()
        let firstWeekday = calendar.component(.weekday, from: grid[0])
        XCTAssertEqual(firstWeekday, 2, "Grid must start on Monday (weekday 2)")
    }

    func testMonthGridContainsAllDaysOfMonth() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 1)

        let grid = vm.monthGridDates()
        let augustDays = grid.filter { vm.isInCurrentMonth($0) }

        // August 2026 has 31 days.
        XCTAssertEqual(augustDays.count, 31)
    }

    func testMonthBoundaryFebruary2025() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2025, month: 2, day: 1)

        let grid = vm.monthGridDates()
        let febDays = grid.filter { vm.isInCurrentMonth($0) }

        // Feb 2025 has 28 days (non-leap).
        XCTAssertEqual(febDays.count, 28)
    }

    func testMonthBoundaryFebruary2024LeapYear() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2024, month: 2, day: 1)

        let grid = vm.monthGridDates()
        let febDays = grid.filter { vm.isInCurrentMonth($0) }

        // Feb 2024 has 29 days (leap year).
        XCTAssertEqual(febDays.count, 29)
    }

    // MARK: - Week View Tests

    func testWeekDatesReturnsSevenDays() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 19) // Wednesday

        let dates = vm.weekDates()
        XCTAssertEqual(dates.count, 7)
    }

    func testWeekDatesStartOnMonday() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 19) // Wednesday

        let dates = vm.weekDates()
        let firstWeekday = calendar.component(.weekday, from: dates[0])
        XCTAssertEqual(firstWeekday, 2, "Week must start on Monday")
    }

    func testWeekDatesEndsOnSunday() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 19)

        let dates = vm.weekDates()
        let lastWeekday = calendar.component(.weekday, from: dates[6])
        XCTAssertEqual(lastWeekday, 1, "Week must end on Sunday")
    }

    // MARK: - 3 Days View Tests

    func testThreeDayDatesReturnsThreeDays() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 19)

        let dates = vm.threeDayDates()
        XCTAssertEqual(dates.count, 3)
    }

    func testThreeDayDatesAreConsecutive() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 19)

        let dates = vm.threeDayDates()
        XCTAssertEqual(calendar.component(.day, from: dates[0]), 19)
        XCTAssertEqual(calendar.component(.day, from: dates[1]), 20)
        XCTAssertEqual(calendar.component(.day, from: dates[2]), 21)
    }

    // MARK: - Navigation Tests

    func testNavigateNextMonthAdvancesOneMonth() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 15)
        vm.viewMode = .month

        vm.navigateNext()

        XCTAssertEqual(calendar.component(.month, from: vm.selectedDate), 9)
        XCTAssertEqual(calendar.component(.year, from: vm.selectedDate), 2026)
    }

    func testNavigatePreviousMonthGoesBackOneMonth() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 15)
        vm.viewMode = .month

        vm.navigatePrevious()

        XCTAssertEqual(calendar.component(.month, from: vm.selectedDate), 7)
    }

    func testNavigateNextWeekAdvancesSevenDays() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 15)
        vm.viewMode = .week

        vm.navigateNext()

        XCTAssertEqual(calendar.component(.day, from: vm.selectedDate), 22)
    }

    func testNavigateNextThreeDaysAdvancesThree() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 15)
        vm.viewMode = .threeDays

        vm.navigateNext()

        XCTAssertEqual(calendar.component(.day, from: vm.selectedDate), 18)
    }

    func testNavigateTodayResetsToCurrentDate() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 12, day: 25)

        vm.navigateToday()

        XCTAssertTrue(calendar.isDateInToday(vm.selectedDate))
    }

    // MARK: - WorkDay Display Tests

    func testWorkDayAppearsInCalendar() throws {
        let (service, _) = makeService()
        _ = try service.createWorkDay(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c5, rules: c5Rules
        )

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 15)
        vm.loadWorkDays()

        let wd = vm.workDay(for: makeDate(year: 2026, month: 8, day: 15))
        XCTAssertNotNil(wd)
        XCTAssertEqual(wd?.shiftCode, "C5")
    }

    // MARK: - C5 Boundary Display Tests

    func testC5Day9DisplaysNormalSchedule() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 9)
        _ = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = date
        vm.loadWorkDays()

        let wd = vm.workDay(for: date)!
        let start = timeComponents(from: wd.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 11, "Day 9 must display normal C5")
        XCTAssertEqual(start.minute, 30)
    }

    func testC5Day10DisplaysSpecialSchedule() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 10)
        _ = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = date
        vm.loadWorkDays()

        let wd = vm.workDay(for: date)!
        let start = timeComponents(from: wd.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 12, "Day 10 must display special C5")
        XCTAssertEqual(start.minute, 0)
    }

    func testC5Day20DisplaysSpecialSchedule() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 20)
        _ = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = date
        vm.loadWorkDays()

        let wd = vm.workDay(for: date)!
        let start = timeComponents(from: wd.resolvedStartDateTime)
        let end = timeComponents(from: wd.resolvedEndDateTime)
        XCTAssertEqual(start.hour, 12)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testC5Day21DisplaysNormalSchedule() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 21)
        _ = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = date
        vm.loadWorkDays()

        let wd = vm.workDay(for: date)!
        let start = timeComponents(from: wd.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 11, "Day 21 must display normal C5")
        XCTAssertEqual(start.minute, 30)
    }

    // MARK: - OFF State Tests

    func testOFFDateReturnsNilWorkDay() {
        let (service, _) = makeService()
        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = makeDate(year: 2026, month: 8, day: 15)
        vm.loadWorkDays()

        let wd = vm.workDay(for: makeDate(year: 2026, month: 8, day: 15))
        XCTAssertNil(wd, "No WorkDay = OFF state")
    }

    // MARK: - Task Independence Tests

    func testTaskFieldDoesNotChangeDisplayedTimes() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Create C5 on day 15 (special schedule: 12:00–21:30).
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // Verify original snapshot.
        let startBefore = timeComponents(from: wd.resolvedStartDateTime)
        let endBefore = timeComponents(from: wd.resolvedEndDateTime)
        XCTAssertEqual(startBefore.hour, 12)
        XCTAssertEqual(startBefore.minute, 0)
        XCTAssertEqual(endBefore.hour, 21)
        XCTAssertEqual(endBefore.minute, 30)

        // Task data (MW) is managed by a separate Task model (TASK-TASK-001).
        // Here we verify that WorkDay's resolved snapshot fields are structurally
        // independent from any task-related operation.
        // Updating the note (a different field) does NOT touch schedule.
        let updated = try service.updateNote(workDayID: wd.id, note: "Some note")

        let startAfter = timeComponents(from: updated.resolvedStartDateTime)
        let endAfter = timeComponents(from: updated.resolvedEndDateTime)
        let breakStartAfter = timeComponents(from: updated.resolvedBreakStartDateTime)
        let breakEndAfter = timeComponents(from: updated.resolvedBreakEndDateTime)

        XCTAssertEqual(startAfter.hour, 12, "Task/Note must not change start time")
        XCTAssertEqual(startAfter.minute, 0)
        XCTAssertEqual(endAfter.hour, 21, "Task/Note must not change end time")
        XCTAssertEqual(endAfter.minute, 30)
        XCTAssertEqual(breakStartAfter.hour, 16, "Task/Note must not change break start")
        XCTAssertEqual(breakStartAfter.minute, 30)
        XCTAssertEqual(breakEndAfter.hour, 17, "Task/Note must not change break end")
        XCTAssertEqual(breakEndAfter.minute, 30)
    }

    func testNoteIsIndependentFromTask() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Create WorkDay with a note.
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules, note: "Meeting at 14:00")

        // Note is stored. Task (MW) will be managed separately by TaskDefinition/WorkDayTask.
        // Verify note does not influence schedule.
        XCTAssertEqual(wd.note, "Meeting at 14:00")
        let start = timeComponents(from: wd.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 12, "Note must not influence schedule resolution")
        XCTAssertEqual(start.minute, 0)
    }

    // MARK: - Note Indicator Tests

    func testWorkDayWithNoteHasNoteContent() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c4, rules: [], note: "Họp team")

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = date
        vm.loadWorkDays()

        let loaded = vm.workDay(for: date)
        XCTAssertNotNil(loaded?.note)
        XCTAssertEqual(loaded?.note, "Họp team")
    }

    func testWorkDayWithoutNoteHasNilNote() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)
        _ = try service.createWorkDay(date: date, shift: c4, rules: [])

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = date
        vm.loadWorkDays()

        let loaded = vm.workDay(for: date)
        XCTAssertNil(loaded?.note)
    }

    // MARK: - Delete Tests

    func testDeleteWorkDayRemovesFromCalendar() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.selectedDate = date
        vm.loadWorkDays()
        XCTAssertNotNil(vm.workDay(for: date))

        // Delete.
        try service.deleteWorkDay(id: wd.id)
        vm.loadWorkDays()

        XCTAssertNil(vm.workDay(for: date), "Deleted WorkDay must not appear in calendar")
    }

    // MARK: - Duplicate Date Tests

    func testCannotCreateDuplicateWorkDayFromCalendar() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        _ = try service.createWorkDay(date: date, shift: c4, rules: [])

        // Attempt duplicate.
        XCTAssertThrowsError(
            try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        ) { error in
            guard case WorkDayRepositoryError.duplicateDate = error else {
                XCTFail("Expected duplicateDate error")
                return
            }
        }
    }

    // MARK: - Next Shift Tests

    func testNextShiftLoadsFirstFutureWorkDay() throws {
        let (service, _) = makeService()

        // Create a WorkDay for tomorrow and day after.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date()))!

        _ = try service.createWorkDay(date: dayAfter, shift: c4, rules: [])
        _ = try service.createWorkDay(date: tomorrow, shift: c1, rules: [])

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.viewMode = .today
        vm.loadWorkDays()

        XCTAssertNotNil(vm.nextShift)
        XCTAssertEqual(vm.nextShift?.shiftCode, "C1", "Next shift should be tomorrow's")
    }

    func testNextShiftIsNilWhenNoFutureWorkDays() {
        let (service, _) = makeService()

        let vm = CalendarViewModel(workDayService: service, calendar: calendar)
        vm.viewMode = .today
        vm.loadWorkDays()

        XCTAssertNil(vm.nextShift)
    }

    // MARK: - Weekday Formatter Tests

    func testVietnameseWeekdayNames() {
        XCTAssertEqual(WeekdayFormatter.fullName(for: 2), "Thứ 2")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 3), "Thứ 3")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 4), "Thứ 4")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 5), "Thứ 5")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 6), "Thứ 6")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 7), "Thứ 7")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 1), "Chủ nhật")
    }

    func testVietnameseShortWeekdayNames() {
        XCTAssertEqual(WeekdayFormatter.shortName(for: 2), "T2")
        XCTAssertEqual(WeekdayFormatter.shortName(for: 1), "CN")
    }

    func testMondayFirstHeaderOrder() {
        XCTAssertEqual(WeekdayFormatter.mondayFirstShortNames, ["T2", "T3", "T4", "T5", "T6", "T7", "CN"])
    }

    // MARK: - DayDetailViewModel Tests

    func testDayDetailSelectShiftResolvesSchedule() {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let shiftLookup: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? = { code in
            switch code {
            case "C5": return (ShiftSeedProvider.makeC5(), [ShiftSeedProvider.makeC5SpecialRule()])
            default: return nil
            }
        }

        let vm = DayDetailViewModel(
            date: date, existingWorkDay: nil,
            workDayService: service, shiftLookup: shiftLookup, calendar: calendar
        )

        vm.selectShift("C5")

        XCTAssertEqual(vm.selectedShiftCode, "C5")
        XCTAssertNotNil(vm.resolvedStart)

        let start = timeComponents(from: vm.resolvedStart!)
        let end = timeComponents(from: vm.resolvedEnd!)
        XCTAssertEqual(start.hour, 12, "Day 15 C5 must resolve to special")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testDayDetailSelectOFFClearsSchedule() {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let vm = DayDetailViewModel(
            date: date, existingWorkDay: nil,
            workDayService: service, shiftLookup: { _ in nil }, calendar: calendar
        )

        vm.selectShift("OFF")

        XCTAssertNil(vm.selectedShiftCode)
        XCTAssertNil(vm.resolvedStart)
        XCTAssertNil(vm.resolvedEnd)
        XCTAssertTrue(vm.hasUnsavedChanges)
    }

    func testDayDetailSaveCreatesWorkDay() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let shiftLookup: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? = { [self] code in
            switch code {
            case "C4": return (c4, [])
            default: return nil
            }
        }

        let vm = DayDetailViewModel(
            date: date, existingWorkDay: nil,
            workDayService: service, shiftLookup: shiftLookup, calendar: calendar
        )

        vm.selectShift("C4")
        let success = vm.save()

        XCTAssertTrue(success)
        XCTAssertEqual(repo.count, 1)

        let created = try repo.fetchByDate(date)
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.shiftCode, "C4")
    }

    func testDayDetailDeleteRequiresConfirmation() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])

        let vm = DayDetailViewModel(
            date: date, existingWorkDay: wd,
            workDayService: service, shiftLookup: { _ in nil }, calendar: calendar
        )

        // Delete requires showDeleteConfirmation = true first, then confirmDelete().
        XCTAssertFalse(vm.showDeleteConfirmation)
        vm.showDeleteConfirmation = true
        XCTAssertTrue(vm.showDeleteConfirmation)

        let success = vm.confirmDelete()
        XCTAssertTrue(success)
        XCTAssertNil(vm.existingWorkDay)
    }

    func testDayDetailUnsavedChangesFlag() {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let vm = DayDetailViewModel(
            date: date, existingWorkDay: nil,
            workDayService: service, shiftLookup: { _ in nil }, calendar: calendar
        )

        XCTAssertFalse(vm.hasUnsavedChanges)

        vm.updateNote("Test")
        XCTAssertTrue(vm.hasUnsavedChanges)
    }

    func testDayDetailTaskFieldIsSeparateFromNote() throws {
        let (service, _) = makeService()
        let taskStore = InMemoryTaskStore(seed: true)
        let taskService = TaskService(store: taskStore)
        let date = makeDate(year: 2026, month: 8, day: 15)

        let shiftLookup: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? = { [self] code in
            code == "C5" ? (c5, c5Rules) : nil
        }

        // Create the WorkDay first (tasks require an existing WorkDay).
        let vm = DayDetailViewModel(
            date: date, existingWorkDay: nil,
            workDayService: service, shiftLookup: shiftLookup,
            taskService: taskService, calendar: calendar
        )
        vm.selectShift("C5")
        vm.updateNote("Họp team")
        XCTAssertTrue(vm.save())
        vm.loadTasks()

        // Assign MW as a structured task (separate from note).
        let mw = taskService.task(withCode: "MW")!
        vm.addTask(mw)

        // Task list and note are independent.
        XCTAssertTrue(vm.assignedTasks.contains { $0.code == "MW" })
        XCTAssertEqual(vm.note, "Họp team")
        XCTAssertFalse(vm.note.contains("MW"), "Task must not be stored in Note")
    }

    func testDayDetailTaskDoesNotAppearInNote() throws {
        let (service, _) = makeService()
        let taskStore = InMemoryTaskStore(seed: true)
        let taskService = TaskService(store: taskStore)
        let date = makeDate(year: 2026, month: 8, day: 15)

        let shiftLookup: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? = { [self] code in
            code == "C5" ? (c5, c5Rules) : nil
        }

        let vm = DayDetailViewModel(
            date: date, existingWorkDay: nil,
            workDayService: service, shiftLookup: shiftLookup,
            taskService: taskService, calendar: calendar
        )

        vm.selectShift("C5")
        vm.updateNote("Meeting")
        XCTAssertTrue(vm.save())
        vm.loadTasks()

        let mw = taskService.task(withCode: "MW")!
        vm.addTask(mw)

        // Verify "MW" is NOT stored in the WorkDay's note.
        let saved = try service.fetchWorkDay(date: date)
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.note, "Meeting", "Note must contain only the note, not the task")
        XCTAssertFalse(saved?.note?.contains("MW") ?? false, "MW must not be in note field")
        // Task is stored in the task service, separately.
        XCTAssertEqual(taskService.tasks(forWorkDay: saved!.id).first?.code, "MW")
    }
}
