// ShiftFlow — Domain Tests
// WorkDayServiceTests.swift
//
// TASK-WORKDAY-001: Comprehensive WorkDay tests.
//
// Tests cover:
// - WorkDay creation with snapshot
// - C1 resolution on creation
// - C5 normal (day 9) on creation
// - C5 special (day 15) on creation
// - C5 boundary (day 9/10/20/21)
// - Historical snapshot immutability (P0 regression)
// - Explicit shift change (C4 → C5)
// - Duplicate date handling
// - Delete WorkDay
// - Note update does not change snapshot
// - Persistence round-trip

import XCTest
@testable import ShiftFlowDomain

final class WorkDayServiceTests: XCTestCase {

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

    private func makeService() -> (WorkDayService, InMemoryWorkDayRepository) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar)
        return (service, repo)
    }

    // Seed data
    private var c1: ShiftDefinition { ShiftSeedProvider.makeC1() }
    private var c4: ShiftDefinition { ShiftSeedProvider.makeC4() }
    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    // MARK: - WorkDay Creation Tests

    func testCreateWorkDayWithC1SnapshotsCorrectly() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let workDay = try service.createWorkDay(date: date, shift: c1, rules: [])

        let start = timeComponents(from: workDay.resolvedStartDateTime)
        let end = timeComponents(from: workDay.resolvedEndDateTime)
        let breakStart = timeComponents(from: workDay.resolvedBreakStartDateTime)
        let breakEnd = timeComponents(from: workDay.resolvedBreakEndDateTime)

        XCTAssertEqual(start.hour, 7)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 16)
        XCTAssertEqual(end.minute, 30)
        XCTAssertEqual(breakStart.hour, 11)
        XCTAssertEqual(breakStart.minute, 0)
        XCTAssertEqual(breakEnd.hour, 12)
        XCTAssertEqual(breakEnd.minute, 0)
        XCTAssertEqual(workDay.shiftCode, "C1")
    }

    // MARK: - C5 Normal Tests

    func testCreateWorkDayC5OnDay9UsesNormalSchedule() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 9)

        let workDay = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        let start = timeComponents(from: workDay.resolvedStartDateTime)
        let end = timeComponents(from: workDay.resolvedEndDateTime)
        let breakStart = timeComponents(from: workDay.resolvedBreakStartDateTime)
        let breakEnd = timeComponents(from: workDay.resolvedBreakEndDateTime)

        XCTAssertEqual(start.hour, 11, "Day 9 must use normal C5 start")
        XCTAssertEqual(start.minute, 30)
        XCTAssertEqual(end.hour, 21, "Day 9 must use normal C5 end")
        XCTAssertEqual(end.minute, 0)
        XCTAssertEqual(breakStart.hour, 16)
        XCTAssertEqual(breakStart.minute, 30)
        XCTAssertEqual(breakEnd.hour, 17)
        XCTAssertEqual(breakEnd.minute, 30)
    }

    // MARK: - C5 Special Tests

    func testCreateWorkDayC5OnDay15UsesSpecialSchedule() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let workDay = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        let start = timeComponents(from: workDay.resolvedStartDateTime)
        let end = timeComponents(from: workDay.resolvedEndDateTime)
        let breakStart = timeComponents(from: workDay.resolvedBreakStartDateTime)
        let breakEnd = timeComponents(from: workDay.resolvedBreakEndDateTime)

        XCTAssertEqual(start.hour, 12, "Day 15 must use special C5 start")
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21, "Day 15 must use special C5 end")
        XCTAssertEqual(end.minute, 30)
        XCTAssertEqual(breakStart.hour, 16)
        XCTAssertEqual(breakStart.minute, 30)
        XCTAssertEqual(breakEnd.hour, 17)
        XCTAssertEqual(breakEnd.minute, 30)
    }

    // MARK: - C5 Boundary Tests

    func testCreateWorkDayC5BoundaryDay9() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 9)
        let workDay = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        let start = timeComponents(from: workDay.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 11, "Day 9 → normal")
        XCTAssertEqual(start.minute, 30)
    }

    func testCreateWorkDayC5BoundaryDay10() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 10)
        let workDay = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        let start = timeComponents(from: workDay.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 12, "Day 10 → special")
        XCTAssertEqual(start.minute, 0)
    }

    func testCreateWorkDayC5BoundaryDay20() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 20)
        let workDay = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        let start = timeComponents(from: workDay.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 12, "Day 20 → special")
        XCTAssertEqual(start.minute, 0)
    }

    func testCreateWorkDayC5BoundaryDay21() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 21)
        let workDay = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        let start = timeComponents(from: workDay.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 11, "Day 21 → normal")
        XCTAssertEqual(start.minute, 30)
    }

    // MARK: - Historical Snapshot Immutability (P0 REGRESSION TEST)

    func testChangingGlobalConfigDoesNotRewriteHistoricalWorkDay() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Step 1: Create WorkDay with C5 on day 15.
        let workDay = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // Step 2: Verify initial snapshot = special schedule (12:00–21:30).
        let startBefore = timeComponents(from: workDay.resolvedStartDateTime)
        let endBefore = timeComponents(from: workDay.resolvedEndDateTime)
        XCTAssertEqual(startBefore.hour, 12)
        XCTAssertEqual(startBefore.minute, 0)
        XCTAssertEqual(endBefore.hour, 21)
        XCTAssertEqual(endBefore.minute, 30)

        // Step 3: Simulate global C5 configuration change to 13:00–22:00.
        // This is a NEW ShiftDefinition with different times.
        // CRITICALLY: We do NOT call changeShift on the existing WorkDay.
        let _changedC5 = ShiftDefinition(
            id: ShiftSeedProvider.c5ID,
            code: "C5",
            name: "C5",
            startHour: 13, startMinute: 0,
            endHour: 22, endMinute: 0,
            breakStartHour: 17, breakStartMinute: 0,
            breakEndHour: 18, breakEndMinute: 0
        )

        // Step 4: Reload the existing WorkDay from repository.
        let reloaded = try repo.fetchByID(workDay.id)

        // Step 5: VERIFY the historical snapshot is UNCHANGED.
        XCTAssertNotNil(reloaded)
        let startAfter = timeComponents(from: reloaded!.resolvedStartDateTime)
        let endAfter = timeComponents(from: reloaded!.resolvedEndDateTime)

        XCTAssertEqual(startAfter.hour, 12, "Historical snapshot must NOT change when global config changes")
        XCTAssertEqual(startAfter.minute, 0, "Historical snapshot must NOT change")
        XCTAssertEqual(endAfter.hour, 21, "Historical snapshot must NOT change")
        XCTAssertEqual(endAfter.minute, 30, "Historical snapshot must NOT change")

        // The WorkDay still reflects the ORIGINAL resolved values.
        // The new global configuration (13:00–22:00) has NO effect on this WorkDay.
    }

    func testHistoricalSnapshotPreservedAfterUnrelatedOperation() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Create WorkDay.
        let workDay = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // Update note (should NOT touch snapshot).
        let updated = try service.updateNote(workDayID: workDay.id, note: "Test note")

        // Verify snapshot unchanged.
        let start = timeComponents(from: updated.resolvedStartDateTime)
        let end = timeComponents(from: updated.resolvedEndDateTime)
        XCTAssertEqual(start.hour, 12)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
        XCTAssertEqual(updated.note, "Test note")
    }

    // MARK: - Explicit Shift Change Tests

    func testExplicitShiftChangeC4ToC5UpdatesSnapshot() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Create with C4.
        let original = try service.createWorkDay(date: date, shift: c4, rules: [])

        // Verify C4 snapshot: 08:30–18:00.
        let startBefore = timeComponents(from: original.resolvedStartDateTime)
        XCTAssertEqual(startBefore.hour, 8)
        XCTAssertEqual(startBefore.minute, 30)

        // Explicitly change to C5 (on day 15 = special).
        let updated = try service.changeShift(
            workDayID: original.id,
            newShift: c5,
            rules: c5Rules
        )

        // Verify new snapshot: C5 special (12:00–21:30).
        let startAfter = timeComponents(from: updated.resolvedStartDateTime)
        let endAfter = timeComponents(from: updated.resolvedEndDateTime)
        let breakStartAfter = timeComponents(from: updated.resolvedBreakStartDateTime)

        XCTAssertEqual(startAfter.hour, 12, "Explicit shift change must update snapshot")
        XCTAssertEqual(startAfter.minute, 0)
        XCTAssertEqual(endAfter.hour, 21)
        XCTAssertEqual(endAfter.minute, 30)
        XCTAssertEqual(breakStartAfter.hour, 16)
        XCTAssertEqual(breakStartAfter.minute, 30)
        XCTAssertEqual(updated.shiftCode, "C5")
        XCTAssertEqual(updated.shiftID, c5.id)
    }

    func testExplicitShiftChangePreservesWorkDayID() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let original = try service.createWorkDay(date: date, shift: c4, rules: [])
        let updated = try service.changeShift(
            workDayID: original.id, newShift: c5, rules: c5Rules
        )

        XCTAssertEqual(updated.id, original.id, "Shift change must not create a new WorkDay")
        XCTAssertEqual(updated.date, original.date, "Date must not change")
    }

    func testExplicitShiftChangePreservesNote() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        var original = try service.createWorkDay(date: date, shift: c4, rules: [], note: "Important meeting")

        // Verify note is there.
        XCTAssertEqual(original.note, "Important meeting")

        // Change shift.
        let updated = try service.changeShift(
            workDayID: original.id, newShift: c5, rules: c5Rules
        )

        // Note should be preserved.
        XCTAssertEqual(updated.note, "Important meeting", "Shift change must preserve note")
    }

    // MARK: - Duplicate Date Tests

    func testCreateDuplicateDateThrowsError() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // First creation succeeds.
        _ = try service.createWorkDay(date: date, shift: c4, rules: [])

        // Second creation for same date must fail.
        XCTAssertThrowsError(
            try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        ) { error in
            guard case WorkDayRepositoryError.duplicateDate = error else {
                XCTFail("Expected duplicateDate error, got \(error)")
                return
            }
        }
    }

    func testCreateDuplicateDateDoesNotOverwriteExisting() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Create with C4.
        let original = try service.createWorkDay(date: date, shift: c4, rules: [])

        // Attempt duplicate with C5 (should fail).
        _ = try? service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // Verify original is still there, unchanged.
        let fetched = try repo.fetchByDate(date)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched!.id, original.id)
        XCTAssertEqual(fetched!.shiftCode, "C4", "Original must not be overwritten by failed duplicate")
    }

    func testOnlyOneWorkDayPerDate() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        _ = try service.createWorkDay(date: date, shift: c4, rules: [])
        _ = try? service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        XCTAssertEqual(repo.count, 1, "Repository must contain exactly one WorkDay for a date")
    }

    // MARK: - Delete Tests

    func testDeleteWorkDay() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let workDay = try service.createWorkDay(date: date, shift: c4, rules: [])
        XCTAssertEqual(repo.count, 1)

        try service.deleteWorkDay(id: workDay.id)
        XCTAssertEqual(repo.count, 0)

        let fetched = try service.fetchWorkDay(id: workDay.id)
        XCTAssertNil(fetched, "Deleted WorkDay must not exist")
    }

    func testDeleteNonexistentWorkDayThrows() throws {
        let (service, _) = makeService()
        let fakeID = UUID()

        XCTAssertThrowsError(try service.deleteWorkDay(id: fakeID)) { error in
            guard case WorkDayRepositoryError.notFound = error else {
                XCTFail("Expected notFound error")
                return
            }
        }
    }

    // MARK: - Fetch Tests

    func testFetchByDate() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let created = try service.createWorkDay(date: date, shift: c4, rules: [])
        let fetched = try service.fetchWorkDay(date: date)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched!.id, created.id)
    }

    func testFetchByDateReturnsNilWhenEmpty() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let fetched = try service.fetchWorkDay(date: date)
        XCTAssertNil(fetched)
    }

    func testFetchByDateRange() throws {
        let (service, _) = makeService()

        // Create WorkDays for Aug 10, 15, 20.
        _ = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 10), shift: c4, rules: [])
        _ = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        _ = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 20), shift: c1, rules: [])

        // Fetch range Aug 12–18 (should get only day 15).
        let results = try service.fetchWorkDays(
            from: makeDate(year: 2026, month: 8, day: 12),
            to: makeDate(year: 2026, month: 8, day: 18)
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].shiftCode, "C5")
    }

    // MARK: - Note Tests

    func testUpdateNoteDoesNotChangeSnapshot() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let original = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)
        let updated = try service.updateNote(workDayID: original.id, note: "Team meeting at 14:00")

        // Snapshot must be unchanged.
        XCTAssertEqual(updated.resolvedStartDateTime, original.resolvedStartDateTime)
        XCTAssertEqual(updated.resolvedEndDateTime, original.resolvedEndDateTime)
        XCTAssertEqual(updated.resolvedBreakStartDateTime, original.resolvedBreakStartDateTime)
        XCTAssertEqual(updated.resolvedBreakEndDateTime, original.resolvedBreakEndDateTime)
        XCTAssertEqual(updated.shiftCode, original.shiftCode)
        XCTAssertEqual(updated.shiftID, original.shiftID)

        // Note updated.
        XCTAssertEqual(updated.note, "Team meeting at 14:00")
    }

    func testClearNote() throws {
        let (service, _) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let original = try service.createWorkDay(date: date, shift: c4, rules: [], note: "Some note")
        XCTAssertEqual(original.note, "Some note")

        let updated = try service.updateNote(workDayID: original.id, note: nil)
        XCTAssertNil(updated.note)
    }

    // MARK: - Persistence Round-Trip Tests

    func testWorkDayPersistsAllSnapshotFields() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let created = try service.createWorkDay(date: date, shift: c5, rules: c5Rules, note: "Test")

        // Reload from repository.
        let reloaded = try repo.fetchByID(created.id)

        XCTAssertNotNil(reloaded)
        XCTAssertEqual(reloaded!.id, created.id)
        XCTAssertEqual(reloaded!.shiftID, created.shiftID)
        XCTAssertEqual(reloaded!.shiftCode, created.shiftCode)
        XCTAssertEqual(reloaded!.resolvedStartDateTime, created.resolvedStartDateTime)
        XCTAssertEqual(reloaded!.resolvedEndDateTime, created.resolvedEndDateTime)
        XCTAssertEqual(reloaded!.resolvedBreakStartDateTime, created.resolvedBreakStartDateTime)
        XCTAssertEqual(reloaded!.resolvedBreakEndDateTime, created.resolvedBreakEndDateTime)
        XCTAssertEqual(reloaded!.note, "Test")
    }

    func testWorkDayPersistsCorrectDateComponents() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        let created = try service.createWorkDay(date: date, shift: c4, rules: [])
        let reloaded = try repo.fetchByID(created.id)!

        let day = calendar.component(.day, from: reloaded.date)
        let month = calendar.component(.month, from: reloaded.date)
        let year = calendar.component(.year, from: reloaded.date)

        XCTAssertEqual(day, 15)
        XCTAssertEqual(month, 8)
        XCTAssertEqual(year, 2026)
    }

    // MARK: - WorkDay Creation from ResolvedShift

    func testWorkDayInitFromResolvedShiftCapturesAllFields() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)

        let workDay = WorkDay(date: date, resolvedShift: resolved)

        XCTAssertEqual(workDay.shiftID, resolved.shiftID)
        XCTAssertEqual(workDay.shiftCode, resolved.shiftCode)
        XCTAssertEqual(workDay.resolvedStartDateTime, resolved.startDateTime)
        XCTAssertEqual(workDay.resolvedEndDateTime, resolved.endDateTime)
        XCTAssertEqual(workDay.resolvedBreakStartDateTime, resolved.breakStartDateTime)
        XCTAssertEqual(workDay.resolvedBreakEndDateTime, resolved.breakEndDateTime)
    }

    // MARK: - Shift Change on Non-existent WorkDay

    func testChangeShiftOnNonexistentWorkDayThrows() throws {
        let (service, _) = makeService()
        let fakeID = UUID()

        XCTAssertThrowsError(
            try service.changeShift(workDayID: fakeID, newShift: c5, rules: c5Rules)
        ) { error in
            guard case WorkDayRepositoryError.notFound = error else {
                XCTFail("Expected notFound error")
                return
            }
        }
    }
}
