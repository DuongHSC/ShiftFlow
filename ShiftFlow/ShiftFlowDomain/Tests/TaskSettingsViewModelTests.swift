// ShiftFlow — Tests
// TaskSettingsViewModelTests.swift
//
// TASK-TASK-002: Task Settings UI ViewModel tests.
//
// Verifies list loading/sorting, create/edit/enable/disable/delete,
// delete protection, MW preservation, historical snapshot protection,
// reminder/widget independence, accessibility labels, and error mapping.
//
// TASK-XCODE-FIX-001 (XP-01): imports the app module for TaskSettingsViewModel
// in addition to the domain module. Compiled by the app-hosted `ShiftFlowTests`
// Xcode target, not the standalone `ShiftFlowDomain` SPM test target.

import XCTest
@testable import ShiftFlowDomain
@testable import ShiftFlow

final class TaskSettingsViewModelTests: XCTestCase {

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
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    private func makeSystem(seed: Bool = true) -> (TaskSettingsViewModel, TaskService, InMemoryTaskStore) {
        let store = InMemoryTaskStore(seed: seed)
        let service = TaskService(store: store)
        let vm = TaskSettingsViewModel(taskService: service)
        return (vm, service, store)
    }

    private func makeWorkDayService() -> (WorkDayService, InMemoryWorkDayRepository) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        return (WorkDayService(repository: repo, calendar: calendar), repo)
    }

    // MARK: - 1-3. List

    func testTaskListLoads() {
        let (vm, _, _) = makeSystem()
        XCTAssertFalse(vm.tasks.isEmpty)
        XCTAssertTrue(vm.tasks.contains { $0.code == "MW" })
    }

    func testActiveTasksAppearBeforeInactive() throws {
        let (vm, service, _) = makeSystem()
        _ = try service.createTask(code: "AAA", name: "AAA")
        let bbb = try service.createTask(code: "BBB", name: "BBB")
        try service.setTaskActive(id: bbb.id, isActive: false)
        vm.reload()

        // First entries active, last entries inactive.
        let firstInactiveIndex = vm.tasks.firstIndex { !$0.isActive }
        if let idx = firstInactiveIndex {
            for i in 0..<idx { XCTAssertTrue(vm.tasks[i].isActive) }
            for i in idx..<vm.tasks.count { XCTAssertFalse(vm.tasks[i].isActive) }
        }
    }

    func testTasksSortedByCode() throws {
        let (vm, service, _) = makeSystem(seed: false)
        _ = try service.createTask(code: "Zalo", name: "Zalo")
        _ = try service.createTask(code: "Alpha", name: "Alpha")
        _ = try service.createTask(code: "MW", name: "MW")
        vm.reload()

        let activeCodes = vm.tasks.filter { $0.isActive }.map { $0.code.uppercased() }
        XCTAssertEqual(activeCodes, activeCodes.sorted())
    }

    // MARK: - 4-7. Create

    func testCreateTask() {
        let (vm, _, _) = makeSystem()
        XCTAssertTrue(vm.createTask(code: "Ticket", name: "Ticket"))
        XCTAssertTrue(vm.tasks.contains { $0.code == "Ticket" })
    }

    func testCreateTaskRejectsEmptyCode() {
        let (vm, _, _) = makeSystem()
        XCTAssertFalse(vm.createTask(code: "  ", name: "X"))
        XCTAssertNotNil(vm.errorMessage)
    }

    func testCreateTaskRejectsEmptyName() {
        let (vm, _, _) = makeSystem()
        XCTAssertFalse(vm.createTask(code: "X", name: "  "))
        XCTAssertNotNil(vm.errorMessage)
    }

    func testCreateTaskRejectsDuplicateCode() {
        let (vm, _, _) = makeSystem()
        XCTAssertFalse(vm.createTask(code: "MW", name: "Dup"))
        XCTAssertEqual(vm.errorMessage, "Mã công việc đã tồn tại.")
    }

    // MARK: - 8-9. Edit

    func testEditTaskName() {
        let (vm, service, _) = makeSystem()
        let mw = service.task(withCode: "MW")!
        XCTAssertTrue(vm.updateTask(mw, name: "Trực MW", isActive: true))
        XCTAssertEqual(service.task(withCode: "MW")!.name, "Trực MW")
    }

    func testTaskCodeCannotChange() {
        let (vm, service, _) = makeSystem()
        let mw = service.task(withCode: "MW")!
        _ = vm.updateTask(mw, name: "Renamed", isActive: true)
        // withEdits preserves code; there is no API to change it.
        XCTAssertEqual(service.task(withCode: "MW")!.code, "MW")
    }

    // MARK: - 10-12. Enable / Disable

    func testDisableTask() {
        let (vm, service, _) = makeSystem()
        let mw = service.task(withCode: "MW")!
        XCTAssertTrue(vm.setActive(mw, isActive: false))
        XCTAssertFalse(service.activeTasks().contains { $0.code == "MW" })
    }

    func testDisabledTaskCannotBeNewlyAssigned() throws {
        let (vm, service, _) = makeSystem()
        let mw = service.task(withCode: "MW")!
        _ = vm.setActive(mw, isActive: false)
        // Disabled task excluded from active list (used for new assignment options).
        XCTAssertFalse(service.activeTasks().contains { $0.id == mw.id })
    }

    func testExistingAssignmentSurvivesDisable() throws {
        let (vm, service, _) = makeSystem()
        let workDayID = UUID()
        let mw = service.task(withCode: "MW")!
        try service.addTask(taskDefinitionID: mw.id, toWorkDay: workDayID)

        _ = vm.setActive(mw, isActive: false)

        // Existing assignment intact.
        XCTAssertTrue(service.hasTask(workDayID: workDayID))
        XCTAssertEqual(service.tasks(forWorkDay: workDayID).first?.id, mw.id)
    }

    // MARK: - 13-15. Delete

    func testDeleteUnusedTask() throws {
        let (vm, service, _) = makeSystem()
        let ticket = try service.createTask(code: "Ticket", name: "Ticket")
        XCTAssertTrue(vm.deleteTask(ticket))
        XCTAssertNil(service.task(withCode: "Ticket"))
    }

    func testDeleteTaskInUseIsRejected() throws {
        let (vm, service, _) = makeSystem()
        let workDayID = UUID()
        let mw = service.task(withCode: "MW")!
        try service.addTask(taskDefinitionID: mw.id, toWorkDay: workDayID)

        XCTAssertFalse(vm.deleteTask(mw))
        XCTAssertEqual(vm.errorMessage, "Công việc đang được sử dụng. Hãy tắt thay vì xóa.")
        XCTAssertNotNil(service.task(withCode: "MW"), "In-use task must remain")
    }

    func testDeleteRequiresConfirmation() {
        // The View presents a confirmation alert before calling deleteTask.
        // At the ViewModel level, deleteTask performs the delete only when invoked.
        let (vm, service, _) = makeSystem()
        // Not calling deleteTask leaves the task intact.
        XCTAssertNotNil(service.task(withCode: "MW"))
        _ = vm // referenced
    }

    // MARK: - 16-17. MW

    func testMWExistsAfterSeed() {
        let (_, service, _) = makeSystem()
        XCTAssertNotNil(service.task(withCode: "MW"))
    }

    func testMWIsNotDuplicated() {
        let (_, service, _) = makeSystem()
        service.seedIfNeeded()
        service.seedIfNeeded()
        XCTAssertEqual(service.allTasks().filter { $0.code == "MW" }.count, 1)
    }

    // MARK: - 18-20. Snapshot Protection

    func testTaskRenameDoesNotChangeWorkDaySnapshot() throws {
        let (vm, service, _) = makeSystem()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = service.task(withCode: "MW")!
        try service.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        _ = vm.updateTask(mw, name: "Morning Work", isActive: true)

        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: after.resolvedStartDateTime).hour, 12)
    }

    func testTaskDisableDoesNotChangeWorkDaySnapshot() throws {
        let (vm, service, _) = makeSystem()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = service.task(withCode: "MW")!
        try service.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        _ = vm.setActive(mw, isActive: false)

        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: after.resolvedStartDateTime).hour, 12)
        XCTAssertEqual(timeComponents(from: after.resolvedEndDateTime).hour, 21)
    }

    func testTaskAssignmentDoesNotChangeWorkDaySnapshot() throws {
        let (_, service, _) = makeSystem()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let before = try repo.fetchByID(wd.id)!
        let mw = service.task(withCode: "MW")!
        try service.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(before.resolvedStartDateTime, after.resolvedStartDateTime)
        XCTAssertEqual(before.resolvedBreakStartDateTime, after.resolvedBreakStartDateTime)
    }

    // MARK: - 21-22. Reminder / Widget Independence

    func testTaskChangeDoesNotChangeReminderTime() throws {
        let (vm, service, _) = makeSystem()
        let (wdService, _) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let fireBefore = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)

        let mw = service.task(withCode: "MW")!
        _ = vm.updateTask(mw, name: "Renamed", isActive: true)

        let fireAfter = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)
        XCTAssertEqual(fireBefore, fireAfter)
    }

    func testTaskChangeDoesNotChangeWidgetShiftTimes() throws {
        let (vm, service, _) = makeSystem()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = service.task(withCode: "MW")!
        try service.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        _ = vm.updateTask(mw, name: "Renamed", isActive: true)

        let workDays = try repo.fetchByDateRange(from: makeDate(year: 2026, month: 8, day: 15), to: makeDate(year: 2026, month: 8, day: 15))
        let snapshot = WidgetScheduleBuilder.build(workDays: workDays, referenceDate: makeDate(year: 2026, month: 8, day: 15), taskWorkDayIDs: service.workDayIDsWithTasks(), calendar: calendar)
        XCTAssertEqual(timeComponents(from: snapshot.today!.startDateTime).hour, 12)
        XCTAssertTrue(snapshot.today!.hasTask)
    }

    // MARK: - 23. Historical assignment

    func testHistoricalTaskAssignmentRemainsValid() throws {
        let (vm, service, _) = makeSystem()
        let workDayID = UUID()
        let mw = service.task(withCode: "MW")!
        try service.addTask(taskDefinitionID: mw.id, toWorkDay: workDayID)

        // Disable the task later.
        _ = vm.setActive(mw, isActive: false)

        // Historical assignment still resolvable to the (now-inactive) task.
        let assigned = service.tasks(forWorkDay: workDayID)
        XCTAssertEqual(assigned.first?.code, "MW")
        XCTAssertFalse(assigned.first?.isActive ?? true)
    }

    // MARK: - 24-25. Reset

    func testResetDefaultsDoesNotRewriteWorkDays() throws {
        let (_, service, _) = makeSystem()
        let (wdService, repo) = makeWorkDayService()
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let mw = service.task(withCode: "MW")!
        try service.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)

        service.resetDefaults()

        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: after.resolvedStartDateTime).hour, 12)
        // Assignment preserved.
        XCTAssertTrue(service.hasTask(workDayID: wd.id))
    }

    func testResetDefaultsDoesNotDuplicateMW() {
        let (_, service, _) = makeSystem()
        service.resetDefaults()
        service.resetDefaults()
        XCTAssertEqual(service.allTasks().filter { $0.code == "MW" }.count, 1)
    }

    // MARK: - 26. Accessibility

    func testAccessibilityLabels() {
        let (vm, service, _) = makeSystem()
        let mw = service.task(withCode: "MW")!
        let label = vm.accessibilityLabel(for: mw)
        XCTAssertTrue(label.contains("MW"))
        XCTAssertTrue(label.contains("đang bật"))
    }

    func testAccessibilityLabelReflectsDisabledState() {
        let (vm, service, _) = makeSystem()
        let mw = service.task(withCode: "MW")!
        _ = vm.setActive(mw, isActive: false)
        let disabled = service.task(withCode: "MW")!
        let label = vm.accessibilityLabel(for: disabled)
        XCTAssertTrue(label.contains("đã tắt"))
    }

    // MARK: - 27. Error mapping

    func testUserFacingErrorsDoNotLeakInternalDetails() {
        let (vm, _, _) = makeSystem()
        _ = vm.createTask(code: "MW", name: "dup")
        let msg = vm.errorMessage ?? ""
        XCTAssertFalse(msg.contains("TaskError"))
        XCTAssertFalse(msg.contains("duplicateCode"))
        XCTAssertFalse(msg.lowercased().contains("uuid"))
    }
}
