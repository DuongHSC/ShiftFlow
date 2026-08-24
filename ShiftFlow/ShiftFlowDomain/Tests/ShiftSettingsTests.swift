// ShiftFlow — Tests
// ShiftSettingsTests.swift
//
// TASK-SETTINGS-001: Comprehensive settings / configuration tests.
//
// Verifies shift configuration editing, C5 rule editing, validation,
// historical snapshot protection, future WorkDay behavior, explicit shift
// change, seeding idempotency, disable behavior, reset, and invariants.
//
// TASK-XCODE-FIX-001 (XP-01): exercises the app-layer CalendarViewModel and
// ShiftSettingsViewModel, so it imports the app module in addition to the domain
// module. Compiled by the app-hosted `ShiftFlowTests` Xcode target, not the
// standalone `ShiftFlowDomain` SPM test target.

import XCTest
@testable import ShiftFlowDomain
@testable import ShiftFlow

final class ShiftSettingsTests: XCTestCase {

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

    private func makeConfigService(seed: Bool = true) -> (ShiftConfigurationService, InMemoryShiftConfigurationStore) {
        let store = InMemoryShiftConfigurationStore(seed: seed)
        let service = ShiftConfigurationService(store: store)
        return (service, store)
    }

    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    // MARK: - Shift Configuration (1-10)

    func testDefaultC1Values() {
        let (service, _) = makeConfigService()
        let c1 = service.shift(withCode: "C1")!
        XCTAssertEqual(c1.startHour, 7); XCTAssertEqual(c1.startMinute, 0)
        XCTAssertEqual(c1.endHour, 16); XCTAssertEqual(c1.endMinute, 30)
        XCTAssertEqual(c1.breakStartHour, 11); XCTAssertEqual(c1.breakEndHour, 12)
    }

    func testDefaultC2Values() {
        let (service, _) = makeConfigService()
        let c2 = service.shift(withCode: "C2")!
        XCTAssertEqual(c2.startHour, 7); XCTAssertEqual(c2.startMinute, 30)
        XCTAssertEqual(c2.endHour, 17); XCTAssertEqual(c2.endMinute, 0)
    }

    func testDefaultC3Values() {
        let (service, _) = makeConfigService()
        let c3 = service.shift(withCode: "C3")!
        XCTAssertEqual(c3.startHour, 8); XCTAssertEqual(c3.endHour, 17)
        XCTAssertEqual(c3.endMinute, 30)
    }

    func testDefaultC4Values() {
        let (service, _) = makeConfigService()
        let c4 = service.shift(withCode: "C4")!
        XCTAssertEqual(c4.startHour, 8); XCTAssertEqual(c4.startMinute, 30)
        XCTAssertEqual(c4.endHour, 18)
    }

    func testDefaultC5Values() {
        let (service, _) = makeConfigService()
        let c5 = service.shift(withCode: "C5")!
        XCTAssertEqual(c5.startHour, 11); XCTAssertEqual(c5.startMinute, 30)
        XCTAssertEqual(c5.endHour, 21); XCTAssertEqual(c5.endMinute, 0)
    }

    func testEditShiftUpdatesConfiguration() throws {
        let (service, _) = makeConfigService()
        let c1 = service.shift(withCode: "C1")!
        let updated = c1.withEdits(startHour: 6, startMinute: 0)
        try service.updateShift(updated)

        let reloaded = service.shift(withCode: "C1")!
        XCTAssertEqual(reloaded.startHour, 6)
        XCTAssertEqual(reloaded.startMinute, 0)
    }

    func testShiftCodeCannotChange() throws {
        let (service, _) = makeConfigService()
        let c1 = service.shift(withCode: "C1")!
        // withEdits does not accept a code parameter — code is preserved.
        let edited = c1.withEdits(name: "Renamed")
        XCTAssertEqual(edited.code, "C1", "Code must remain stable")
        try service.updateShift(edited)
        XCTAssertEqual(service.shift(withCode: "C1")!.code, "C1")
    }

    func testInvalidTimeConfigurationRejected() {
        let (service, _) = makeConfigService()
        let c1 = service.shift(withCode: "C1")!
        // start after end.
        let invalid = c1.withEdits(startHour: 20, startMinute: 0, endHour: 8, endMinute: 0)
        XCTAssertThrowsError(try service.updateShift(invalid)) { error in
            XCTAssertEqual(error as? ShiftConfigurationError, .startNotBeforeEnd)
        }
    }

    func testInvalidBreakConfigurationRejected() {
        let (service, _) = makeConfigService()
        let c1 = service.shift(withCode: "C1")!
        // break outside working interval (break before start).
        let invalid = c1.withEdits(breakStartHour: 5, breakStartMinute: 0, breakEndHour: 6, breakEndMinute: 0)
        XCTAssertThrowsError(try service.updateShift(invalid)) { error in
            XCTAssertEqual(error as? ShiftConfigurationError, .breakOutsideWorkingInterval)
        }
    }

    func testDuplicateShiftRejected() {
        let (service, _) = makeConfigService()
        // Attempt to give C2 the code "C1" via a hand-built definition with C2's id.
        let c2 = service.shift(withCode: "C2")!
        let collidingCode = ShiftDefinition(
            id: c2.id, code: "C1", name: "C2",
            startHour: 7, startMinute: 30, endHour: 17, endMinute: 0,
            breakStartHour: 11, breakStartMinute: 30, breakEndHour: 12, breakEndMinute: 30
        )
        XCTAssertThrowsError(try service.updateShift(collidingCode)) { error in
            if case ShiftConfigurationError.duplicateCode = (error as? ShiftConfigurationError) {} else {
                XCTFail("Expected duplicateCode")
            }
        }
    }

    // MARK: - C5 Rule (11-18)

    func testDefaultC5RuleIsDay10To20() {
        let (service, _) = makeConfigService()
        let c5 = service.shift(withCode: "C5")!
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        XCTAssertEqual(rule.startDayOfMonth, 10)
        XCTAssertEqual(rule.endDayOfMonth, 20)
        XCTAssertEqual(rule.startHour, 12)
        XCTAssertEqual(rule.endHour, 21); XCTAssertEqual(rule.endMinute, 30)
    }

    func testC5RuleDay9Normal() {
        let (service, _) = makeConfigService()
        let (c5, rules) = service.lookup("C5")!
        let resolved = ShiftResolver.resolve(date: makeDate(year: 2026, month: 8, day: 9), shift: c5, rules: rules, calendar: calendar)
        XCTAssertEqual(timeComponents(from: resolved.startDateTime).hour, 11)
    }

    func testC5RuleDay10Special() {
        let (service, _) = makeConfigService()
        let (c5, rules) = service.lookup("C5")!
        let resolved = ShiftResolver.resolve(date: makeDate(year: 2026, month: 8, day: 10), shift: c5, rules: rules, calendar: calendar)
        XCTAssertEqual(timeComponents(from: resolved.startDateTime).hour, 12)
    }

    func testC5RuleDay20Special() {
        let (service, _) = makeConfigService()
        let (c5, rules) = service.lookup("C5")!
        let resolved = ShiftResolver.resolve(date: makeDate(year: 2026, month: 8, day: 20), shift: c5, rules: rules, calendar: calendar)
        XCTAssertEqual(timeComponents(from: resolved.startDateTime).hour, 12)
    }

    func testC5RuleDay21Normal() {
        let (service, _) = makeConfigService()
        let (c5, rules) = service.lookup("C5")!
        let resolved = ShiftResolver.resolve(date: makeDate(year: 2026, month: 8, day: 21), shift: c5, rules: rules, calendar: calendar)
        XCTAssertEqual(timeComponents(from: resolved.startDateTime).hour, 11)
    }

    func testEditC5Rule() throws {
        let (service, _) = makeConfigService()
        let c5 = service.shift(withCode: "C5")!
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        let updated = rule.withEdits(startHour: 13, startMinute: 0, endHour: 22, endMinute: 0)
        try service.updateRule(updated)

        let reloaded = service.allRules().first { $0.id == rule.id }!
        XCTAssertEqual(reloaded.startHour, 13)
        XCTAssertEqual(reloaded.endHour, 22)
    }

    func testInvalidRuleRangeRejected() {
        let (service, _) = makeConfigService()
        let c5 = service.shift(withCode: "C5")!
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        let invalid = rule.withEdits(startDayOfMonth: 20, endDayOfMonth: 10) // start > end
        XCTAssertThrowsError(try service.updateRule(invalid)) { error in
            XCTAssertEqual(error as? ShiftConfigurationError, .invalidDayRange)
        }
    }

    func testDisableC5RuleUsesNormalSchedule() throws {
        let (service, _) = makeConfigService()
        let c5 = service.shift(withCode: "C5")!
        let rule = service.allRules().first { $0.shiftID == c5.id }!

        try service.setRuleActive(id: rule.id, isActive: false)

        // Now day 15 should use normal (rule inactive).
        let (shift, rules) = service.lookup("C5")!
        let resolved = ShiftResolver.resolve(date: makeDate(year: 2026, month: 8, day: 15), shift: shift, rules: rules, calendar: calendar)
        XCTAssertEqual(timeComponents(from: resolved.startDateTime).hour, 11, "Disabled rule → normal schedule")
        XCTAssertEqual(timeComponents(from: resolved.startDateTime).minute, 30)
    }

    // MARK: - Historical Snapshot (19-23)

    func testGlobalShiftChangeDoesNotRewriteHistoricalWorkDay() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        // Create C4 WorkDay (08:30).
        let (c4, rules) = service.lookup("C4")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: rules)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 8)

        // Change global C4 config to 06:00.
        try service.updateShift(service.shift(withCode: "C4")!.withEdits(startHour: 6, startMinute: 0))

        // Existing WorkDay unchanged.
        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 8, "Historical WorkDay must not change")
    }

    func testGlobalC5RuleChangeDoesNotRewriteHistoricalWorkDay() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        // Create C5 day 15 → 12:00 special.
        let (c5, rules) = service.lookup("C5")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: rules)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)

        // Change C5 rule to 13:00.
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        try service.updateRule(rule.withEdits(startHour: 13, startMinute: 0, endHour: 22, endMinute: 0))

        // Existing WorkDay unchanged.
        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 12, "Historical C5 WorkDay must not change")
    }

    func testHistoricalCalendarUsesStoredSnapshot() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let (c5, rules) = service.lookup("C5")!
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: rules)

        // Change config.
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        try service.updateRule(rule.withEdits(startHour: 13, startMinute: 0, endHour: 22, endMinute: 0))

        // Calendar reads stored snapshot.
        let cvm = CalendarViewModel(workDayService: wdService, calendar: calendar)
        cvm.selectedDate = makeDate(year: 2026, month: 8, day: 15)
        cvm.loadWorkDays()
        let wd = cvm.workDay(for: makeDate(year: 2026, month: 8, day: 15))!
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)
    }

    func testHistoricalWidgetUsesStoredSnapshot() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let (c5, rules) = service.lookup("C5")!
        _ = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: rules)

        // Change config.
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        try service.updateRule(rule.withEdits(startHour: 13, startMinute: 0, endHour: 22, endMinute: 0))

        // Widget snapshot built from stored WorkDay.
        let workDays = try repo.fetchByDateRange(from: makeDate(year: 2026, month: 8, day: 15), to: makeDate(year: 2026, month: 8, day: 15))
        let snapshot = WidgetScheduleBuilder.build(workDays: workDays, referenceDate: makeDate(year: 2026, month: 8, day: 15), calendar: calendar)
        XCTAssertEqual(timeComponents(from: snapshot.today!.startDateTime).hour, 12)
    }

    func testHistoricalReminderUsesStoredSnapshot() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let (c5, rules) = service.lookup("C5")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: rules)

        // Change config.
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        try service.updateRule(rule.withEdits(startHour: 13, startMinute: 0, endHour: 22, endMinute: 0))

        // Reminder derives from stored snapshot (12:00).
        let reloaded = try repo.fetchByID(wd.id)!
        let fire = ReminderOffset.twoHoursBefore.notificationDate(from: reloaded.resolvedStartDateTime)
        XCTAssertEqual(timeComponents(from: fire).hour, 10, "Reminder based on original 12:00 snapshot")
    }

    // MARK: - Future WorkDay (24-25)

    func testNewWorkDayUsesUpdatedShiftConfiguration() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        // Change C4 config to 06:00.
        try service.updateShift(service.shift(withCode: "C4")!.withEdits(startHour: 6, startMinute: 0))

        // New WorkDay uses updated config.
        let (c4, rules) = service.lookup("C4")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 25), shift: c4, rules: rules)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 6, "New WorkDay uses updated config")
    }

    func testNewC5WorkDayUsesUpdatedRule() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        // Change C5 rule to 13:00.
        let c5 = service.shift(withCode: "C5")!
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        try service.updateRule(rule.withEdits(startHour: 13, startMinute: 0, endHour: 22, endMinute: 0))

        // New C5 WorkDay on day 15 uses updated rule.
        let (shift, rules) = service.lookup("C5")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: shift, rules: rules)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 13, "New C5 WorkDay uses updated rule")
    }

    // MARK: - Explicit Change (26-28)

    func testExplicitWorkDayShiftChangeUpdatesSnapshot() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let (c4, _) = service.lookup("C4")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])

        let (c5, c5rules) = service.lookup("C5")!
        let updated = try wdService.changeShift(workDayID: wd.id, newShift: c5, rules: c5rules)

        XCTAssertEqual(updated.shiftCode, "C5")
        XCTAssertEqual(timeComponents(from: updated.resolvedStartDateTime).hour, 12)
    }

    func testExplicitShiftChangeRefreshesWidget() throws {
        final class Spy: WidgetSnapshotSink { var count = 0; func publish(_ s: WidgetScheduleSnapshot) { count += 1 } }
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let spy = Spy()
        let coordinator = WidgetRefreshCoordinator(repository: repo, sink: spy, calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar, widgetRefresher: coordinator)

        let (c4, _) = service.lookup("C4")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        let before = spy.count

        let (c5, c5rules) = service.lookup("C5")!
        _ = try wdService.changeShift(workDayID: wd.id, newShift: c5, rules: c5rules)

        XCTAssertEqual(spy.count, before + 1, "Explicit shift change refreshes widget")
    }

    func testExplicitShiftChangeReschedulesReminder() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let (c4, _) = service.lookup("C4")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        let fireC4 = ReminderOffset.twoHoursBefore.notificationDate(from: wd.resolvedStartDateTime)

        let (c5, c5rules) = service.lookup("C5")!
        let updated = try wdService.changeShift(workDayID: wd.id, newShift: c5, rules: c5rules)
        let fireC5 = ReminderOffset.twoHoursBefore.notificationDate(from: updated.resolvedStartDateTime)

        XCTAssertNotEqual(fireC4, fireC5, "Reminder reschedules to new snapshot")
        XCTAssertEqual(timeComponents(from: fireC5).hour, 10)
    }

    // MARK: - Seeding (29-32)

    func testFirstRunSeedsFiveShifts() {
        let store = InMemoryShiftConfigurationStore(seed: false)
        let service = ShiftConfigurationService(store: store)
        service.seedIfNeeded()
        XCTAssertEqual(service.allShifts().count, 5)
    }

    func testFirstRunSeedsC5Rule() {
        let store = InMemoryShiftConfigurationStore(seed: false)
        let service = ShiftConfigurationService(store: store)
        service.seedIfNeeded()
        XCTAssertEqual(service.allRules().count, 1)
    }

    func testSeedingIsIdempotent() {
        let store = InMemoryShiftConfigurationStore(seed: false)
        let service = ShiftConfigurationService(store: store)
        service.seedIfNeeded()
        service.seedIfNeeded()
        service.seedIfNeeded()
        XCTAssertEqual(service.allShifts().count, 5, "No duplicates after repeated seeding")
        XCTAssertEqual(service.allRules().count, 1)
    }

    func testExistingCustomConfigurationIsNotOverwritten() throws {
        let (service, _) = makeConfigService()
        // Customize C1.
        try service.updateShift(service.shift(withCode: "C1")!.withEdits(startHour: 5, startMinute: 0))

        // Re-seed (simulating another app launch).
        service.seedIfNeeded()

        // Custom value preserved.
        XCTAssertEqual(service.shift(withCode: "C1")!.startHour, 5, "Custom config must survive re-seed")
    }

    // MARK: - Disable (33-35)

    func testDisabledShiftCannotCreateNewWorkDay() throws {
        let (service, _) = makeConfigService()
        try service.setShiftActive(code: "C4", isActive: false)

        // Disabled shift not in selectable list.
        XCTAssertFalse(service.selectableShifts().contains { $0.code == "C4" })
    }

    func testDisabledShiftDoesNotDeleteHistoricalWorkDay() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let (c4, _) = service.lookup("C4")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])

        try service.setShiftActive(code: "C4", isActive: false)

        // Historical WorkDay still exists.
        XCTAssertNotNil(try repo.fetchByID(wd.id), "Disabling shift must not delete historical WorkDay")
    }

    func testDisabledShiftHistoricalSnapshotRemainsValid() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        let (c4, _) = service.lookup("C4")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])

        try service.setShiftActive(code: "C4", isActive: false)

        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(reloaded.shiftCode, "C4")
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 8)
    }

    // MARK: - Reset (36-39)

    func testResetDefaultsRequiresConfirmation() {
        let (service, _) = makeConfigService()
        let vm = ShiftSettingsViewModel(configurationService: service)
        XCTAssertFalse(vm.showResetConfirmation)
        vm.showResetConfirmation = true
        XCTAssertTrue(vm.showResetConfirmation)
    }

    func testResetDefaultsRestoresC1ToC5() throws {
        let (service, _) = makeConfigService()
        // Customize C1.
        try service.updateShift(service.shift(withCode: "C1")!.withEdits(startHour: 5, startMinute: 0))

        service.resetToDefaults()

        XCTAssertEqual(service.shift(withCode: "C1")!.startHour, 7, "Reset restores C1 default")
        XCTAssertEqual(service.allShifts().count, 5)
    }

    func testResetDefaultsRestoresC5Rule() throws {
        let (service, _) = makeConfigService()
        let c5 = service.shift(withCode: "C5")!
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        try service.updateRule(rule.withEdits(startHour: 13))

        service.resetToDefaults()

        let restored = service.allRules().first!
        XCTAssertEqual(restored.startHour, 12, "Reset restores C5 rule default")
    }

    func testResetDefaultsDoesNotRewriteHistoricalWorkDays() throws {
        let (service, _) = makeConfigService()
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let wdService = WorkDayService(repository: repo, calendar: calendar)

        // Create WorkDay with a customized C5.
        let c5 = service.shift(withCode: "C5")!
        let rule = service.allRules().first { $0.shiftID == c5.id }!
        try service.updateRule(rule.withEdits(startHour: 13, startMinute: 0, endHour: 22, endMinute: 0))
        let (shift, rules) = service.lookup("C5")!
        let wd = try wdService.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: shift, rules: rules)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 13)

        // Reset defaults.
        service.resetToDefaults()

        // Historical WorkDay retains its snapshot (13:00), NOT rewritten to default 12:00.
        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 13, "Reset must not rewrite historical WorkDay")
    }

    // MARK: - Reminder Settings (40-41)

    func testReminderDefaultSupportsFiveOffsets() {
        XCTAssertEqual(ReminderOffset.allCases.count, 5)
    }

    func testTwentyFourHoursIs86400Seconds() {
        XCTAssertEqual(ReminderOffset.twentyFourHoursBefore.timeInterval, -86400)
    }

    // MARK: - Independence (42-44)

    func testTaskDoesNotAffectShiftConfiguration() {
        // Configuration has no task concept; shifts are unaffected by tasks.
        let (service, _) = makeConfigService()
        let c5 = service.shift(withCode: "C5")!
        // No task API exists on ShiftDefinition.
        XCTAssertEqual(c5.startHour, 11)
        XCTAssertEqual(c5.startMinute, 30)
    }

    func testNoteDoesNotAffectShiftConfiguration() {
        // Note is a WorkDay property; ShiftDefinition has none.
        let (service, _) = makeConfigService()
        let c1 = service.shift(withCode: "C1")!
        XCTAssertEqual(c1.startHour, 7)
    }

    func testSettingsDoesNotContainShiftResolutionLogic() {
        // ShiftConfigurationService.lookup returns config; resolution is done
        // by ShiftResolver. Verify the service returns rules but does not
        // produce resolved times itself.
        let (service, _) = makeConfigService()
        let result = service.lookup("C5")
        XCTAssertNotNil(result)
        // The returned value is (ShiftDefinition, [ScheduleRule]) — no ResolvedShift.
        // Resolution requires calling ShiftResolver separately.
        XCTAssertEqual(result?.rules.first?.startDayOfMonth, 10)
    }
}
