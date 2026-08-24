// ShiftFlow — Tests
// PersistenceMappingTests.swift
//
// TASK-PERSISTENCE-001: Persistence-logic tests that are runnable without
// SwiftData/Xcode.
//
// These verify seed/reset/independence LOGIC against the in-memory stores
// (which conform to the same protocols as the SwiftData stores) plus the
// domain-value invariants the @Model mappers must preserve.
//
// SwiftData @Model round-trip, app-relaunch persistence, and CloudKit mirroring
// require macOS/Xcode and are PENDING (see PersistenceTests notes in report).

import XCTest
@testable import ShiftFlowDomain

final class PersistenceMappingTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 0; c.minute = 0; c.second = 0
        return calendar.date(from: c)!
    }

    private func timeComponents(from date: Date) -> (hour: Int, minute: Int) {
        (calendar.component(.hour, from: date), calendar.component(.minute, from: date))
    }

    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    // MARK: - Seed against a store (protocol-level; SwiftData store conforms identically)

    func testFirstLaunchSeedsDefaults() {
        let store = InMemoryShiftConfigurationStore(seed: false)
        let service = ShiftConfigurationService(store: store)
        service.seedIfNeeded()
        XCTAssertEqual(service.allShifts().count, 5)
        XCTAssertEqual(service.allRules().count, 1)
    }

    func testSecondLaunchDoesNotDuplicateDefaults() {
        let store = InMemoryShiftConfigurationStore(seed: false)
        let service = ShiftConfigurationService(store: store)
        service.seedIfNeeded()
        service.seedIfNeeded() // simulate relaunch re-seed
        XCTAssertEqual(service.allShifts().count, 5)
        XCTAssertEqual(service.allRules().count, 1)
    }

    func testMWIsNotDuplicated() {
        let store = InMemoryTaskStore(seed: false)
        let service = TaskService(store: store)
        service.seedIfNeeded()
        service.seedIfNeeded()
        XCTAssertEqual(service.allTasks().filter { $0.code == "MW" }.count, 1)
    }

    func testCustomTaskSurvivesReseed() throws {
        let store = InMemoryTaskStore(seed: true)
        let service = TaskService(store: store)
        _ = try service.createTask(code: "Ticket", name: "Ticket")
        service.seedIfNeeded() // relaunch
        XCTAssertNotNil(service.task(withCode: "Ticket"))
        XCTAssertEqual(service.allTasks().count, 2)
    }

    func testCustomShiftConfigurationSurvivesReseed() throws {
        let store = InMemoryShiftConfigurationStore(seed: true)
        let service = ShiftConfigurationService(store: store)
        try service.updateShift(service.shift(withCode: "C1")!.withEdits(startHour: 5, startMinute: 0))
        service.seedIfNeeded() // relaunch
        XCTAssertEqual(service.shift(withCode: "C1")!.startHour, 5)
    }

    // MARK: - Reset persists via store

    func testResetDefaultsRestoresConfig() throws {
        let store = InMemoryShiftConfigurationStore(seed: true)
        let service = ShiftConfigurationService(store: store)
        try service.updateShift(service.shift(withCode: "C1")!.withEdits(startHour: 5))
        service.resetToDefaults()
        XCTAssertEqual(service.shift(withCode: "C1")!.startHour, 7)
    }

    func testResetDefaultsDoesNotDuplicateMW() {
        let store = InMemoryTaskStore(seed: true)
        let service = TaskService(store: store)
        service.resetDefaults()
        service.resetDefaults()
        XCTAssertEqual(service.allTasks().filter { $0.code == "MW" }.count, 1)
    }

    // MARK: - Historical snapshot independence (config/task change)

    func testConfigChangeDoesNotRewriteHistoricalWorkDay() throws {
        let configStore = InMemoryShiftConfigurationStore(seed: true)
        let configService = ShiftConfigurationService(store: configStore)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let (shift, rules) = configService.lookup("C5")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: shift, rules: rules)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)

        // Change persisted config; existing WorkDay must not change.
        try configService.updateShift(configService.shift(withCode: "C5")!.withEdits(startHour: 13, startMinute: 0, endHour: 22, endMinute: 0))
        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 12)
    }

    func testNewWorkDayUsesUpdatedPersistedConfig() throws {
        let configStore = InMemoryShiftConfigurationStore(seed: true)
        let configService = ShiftConfigurationService(store: configStore)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        // Change C4 config to 06:00, then create a new WorkDay.
        try configService.updateShift(configService.shift(withCode: "C4")!.withEdits(startHour: 6, startMinute: 0))
        let (c4, rules) = configService.lookup("C4")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 25), shift: c4, rules: rules)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 6)
    }

    func testPersistedTaskAssignmentDoesNotChangeSnapshot() throws {
        let taskStore = InMemoryTaskStore(seed: true)
        let taskService = TaskService(store: taskStore)
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        let before = try repo.fetchByID(wd.id)!
        let mw = taskService.task(withCode: "MW")!
        try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
        let after = try repo.fetchByID(wd.id)!
        XCTAssertEqual(before.resolvedStartDateTime, after.resolvedStartDateTime)
    }

    // MARK: - Domain value invariants the @Model mappers must preserve

    func testShiftDefinitionValueRoundTripStable() {
        // The @Model mapper (init(from:)/toDomain) must preserve all fields.
        // Here we assert the domain value is fully described by its fields so a
        // faithful mapper reproduces it exactly.
        let original = ShiftSeedProvider.makeC5()
        let copy = ShiftDefinition(
            id: original.id, code: original.code, name: original.name,
            startHour: original.startHour, startMinute: original.startMinute,
            endHour: original.endHour, endMinute: original.endMinute,
            breakStartHour: original.breakStartHour, breakStartMinute: original.breakStartMinute,
            breakEndHour: original.breakEndHour, breakEndMinute: original.breakEndMinute,
            isActive: original.isActive, createdAt: original.createdAt, modifiedAt: original.modifiedAt
        )
        XCTAssertEqual(original, copy)
    }

    func testScheduleRuleValueRoundTripStable() {
        let original = ShiftSeedProvider.makeC5SpecialRule()
        let copy = ScheduleRule(
            id: original.id, shiftID: original.shiftID,
            startDayOfMonth: original.startDayOfMonth, endDayOfMonth: original.endDayOfMonth,
            startHour: original.startHour, startMinute: original.startMinute,
            endHour: original.endHour, endMinute: original.endMinute,
            breakStartHour: original.breakStartHour, breakStartMinute: original.breakStartMinute,
            breakEndHour: original.breakEndHour, breakEndMinute: original.breakEndMinute,
            priority: original.priority, isActive: original.isActive
        )
        XCTAssertEqual(original, copy)
    }

    func testTaskDefinitionValueRoundTripStable() {
        let original = TaskSeedProvider.makeMW()
        let copy = TaskDefinition(
            id: original.id, code: original.code, name: original.name,
            isActive: original.isActive, createdAt: original.createdAt, modifiedAt: original.modifiedAt
        )
        XCTAssertEqual(original, copy)
    }

    func testWorkDayTaskValueRoundTripStable() {
        let original = WorkDayTask(workDayID: UUID(), taskDefinitionID: UUID())
        let copy = WorkDayTask(
            id: original.id, workDayID: original.workDayID,
            taskDefinitionID: original.taskDefinitionID,
            createdAt: original.createdAt, modifiedAt: original.modifiedAt
        )
        XCTAssertEqual(original, copy)
    }

    func testMWStableUUIDUnchanged() {
        XCTAssertEqual(TaskSeedProvider.makeMW().id, TaskSeedProvider.mwID)
        XCTAssertEqual(TaskSeedProvider.makeMW().id, UUID(uuidString: "00000010-0010-0010-0010-000000000010"))
    }

    func testSeedShiftStableUUIDs() {
        XCTAssertEqual(ShiftSeedProvider.makeC1().id, ShiftSeedProvider.c1ID)
        XCTAssertEqual(ShiftSeedProvider.makeC5().id, ShiftSeedProvider.c5ID)
        XCTAssertEqual(ShiftSeedProvider.makeC5SpecialRule().id, ShiftSeedProvider.c5SpecialRuleID)
    }
}
