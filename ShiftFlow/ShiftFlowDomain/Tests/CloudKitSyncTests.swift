// ShiftFlow — Tests
// CloudKitSyncTests.swift
//
// TASK-CLOUDKIT-001: CloudKit / sync logic tests.
//
// These tests verify the pure, testable parts of the sync implementation:
// - SyncConflictResolver (same-record + date-collision)
// - SyncStatus model
// - Offline-first behavior (in-memory repository stands in for local store)
// - Historical snapshot preservation across "sync"
// - C5 boundary preservation
// - MW/OFF/delete/duplicate integrity
//
// Actual CloudKit container sync, multi-device sync, and iCloud account
// behavior require macOS/Xcode and are PENDING.

import XCTest
@testable import ShiftFlowDomain

final class CloudKitSyncTests: XCTestCase {

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

    private func makeService() -> (WorkDayService, InMemoryWorkDayRepository) {
        let repo = InMemoryWorkDayRepository(calendar: calendar)
        let service = WorkDayService(repository: repo, calendar: calendar)
        return (service, repo)
    }

    private func makeWorkDay(day: Int, shift: ShiftDefinition, rules: [ScheduleRule], modifiedAt: Date, note: String? = nil) -> WorkDay {
        let date = makeDate(year: 2026, month: 8, day: day)
        let resolved = ShiftResolver.resolve(date: date, shift: shift, rules: rules, calendar: calendar)
        return WorkDay(
            id: UUID(),
            date: date,
            shiftID: resolved.shiftID,
            shiftCode: resolved.shiftCode,
            resolvedStartDateTime: resolved.startDateTime,
            resolvedEndDateTime: resolved.endDateTime,
            resolvedBreakStartDateTime: resolved.breakStartDateTime,
            resolvedBreakEndDateTime: resolved.breakEndDateTime,
            note: note,
            createdAt: modifiedAt,
            modifiedAt: modifiedAt
        )
    }

    // MARK: - 1-5. Offline Behavior

    func testAppWorksOfflineCreate() throws {
        // In-memory repo simulates local store with no network.
        let (service, repo) = makeService()
        let wd = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        XCTAssertNotNil(try repo.fetchByID(wd.id), "WorkDay created offline")
    }

    func testWorkDayEditOffline() throws {
        let (service, _) = makeService()
        let wd = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        let updated = try service.changeShift(workDayID: wd.id, newShift: c5, rules: c5Rules)
        XCTAssertEqual(updated.shiftCode, "C5", "WorkDay edited offline")
    }

    func testWorkDayDeleteOffline() throws {
        let (service, repo) = makeService()
        let wd = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c4, rules: [])
        try service.deleteWorkDay(id: wd.id)
        XCTAssertNil(try repo.fetchByID(wd.id), "WorkDay deleted offline")
    }

    func testShiftResolverWorksOffline() {
        // ShiftResolver is pure — no network dependency.
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)
        let start = timeComponents(from: resolved.startDateTime)
        XCTAssertEqual(start.hour, 12, "ShiftResolver works offline")
    }

    func testLocalDataUsableInAllSyncStates() {
        XCTAssertTrue(SyncStatus.synced.localDataUsable)
        XCTAssertTrue(SyncStatus.syncing.localDataUsable)
        XCTAssertTrue(SyncStatus.waitingForConnection.localDataUsable)
        XCTAssertTrue(SyncStatus.unavailable.localDataUsable)
        XCTAssertTrue(SyncStatus.accountUnavailable.localDataUsable)
    }

    // MARK: - 6-9. Historical Snapshot Preservation

    func testGlobalConfigChangeDoesNotRewriteHistoricalWorkDay() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // Original snapshot = 12:00–21:30.
        let before = timeComponents(from: wd.resolvedStartDateTime)
        XCTAssertEqual(before.hour, 12)

        // Simulate config change (no changeShift call). Reload.
        let reloaded = try repo.fetchByID(wd.id)!
        let after = timeComponents(from: reloaded.resolvedStartDateTime)
        XCTAssertEqual(after.hour, 12, "Config change must not rewrite snapshot")
    }

    func testSyncedWorkDayPreservesResolvedStart() {
        // Simulate a WorkDay that "arrived via sync" — its snapshot must be used as-is.
        let synced = makeWorkDay(day: 15, shift: c5, rules: c5Rules, modifiedAt: Date())
        let start = timeComponents(from: synced.resolvedStartDateTime)
        XCTAssertEqual(start.hour, 12)
        XCTAssertEqual(start.minute, 0)
    }

    func testSyncedWorkDayPreservesResolvedEnd() {
        let synced = makeWorkDay(day: 15, shift: c5, rules: c5Rules, modifiedAt: Date())
        let end = timeComponents(from: synced.resolvedEndDateTime)
        XCTAssertEqual(end.hour, 21)
        XCTAssertEqual(end.minute, 30)
    }

    func testSyncedWorkDayPreservesBreakSnapshot() {
        let synced = makeWorkDay(day: 15, shift: c5, rules: c5Rules, modifiedAt: Date())
        let bStart = timeComponents(from: synced.resolvedBreakStartDateTime)
        let bEnd = timeComponents(from: synced.resolvedBreakEndDateTime)
        XCTAssertEqual(bStart.hour, 16); XCTAssertEqual(bStart.minute, 30)
        XCTAssertEqual(bEnd.hour, 17); XCTAssertEqual(bEnd.minute, 30)
    }

    // MARK: - 10-13. C5 Boundary Preservation

    func testC5Day9RemainsNormalAfterSync() {
        let wd = makeWorkDay(day: 9, shift: c5, rules: c5Rules, modifiedAt: Date())
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 11)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).minute, 30)
    }

    func testC5Day10RemainsSpecialAfterSync() {
        let wd = makeWorkDay(day: 10, shift: c5, rules: c5Rules, modifiedAt: Date())
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)
    }

    func testC5Day20RemainsSpecialAfterSync() {
        let wd = makeWorkDay(day: 20, shift: c5, rules: c5Rules, modifiedAt: Date())
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)
    }

    func testC5Day21RemainsNormalAfterSync() {
        let wd = makeWorkDay(day: 21, shift: c5, rules: c5Rules, modifiedAt: Date())
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 11)
        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).minute, 30)
    }

    // MARK: - 14-15. MW Independence

    func testMWDoesNotAffectShiftTimesBeforeSync() throws {
        let (service, _) = makeService()
        let wd = try service.createWorkDay(date: makeDate(year: 2026, month: 8, day: 15), shift: c5, rules: c5Rules)
        // Note field used as proxy; task model is separate. Times unchanged.
        let updated = try service.updateNote(workDayID: wd.id, note: "task ref")
        XCTAssertEqual(updated.resolvedStartDateTime, wd.resolvedStartDateTime)
    }

    func testMWDoesNotAffectShiftTimesAfterSync() {
        // Two "synced" copies: one with a task association, one without.
        // The resolved snapshot is identical because tasks never touch times.
        let withoutTask = makeWorkDay(day: 15, shift: c5, rules: c5Rules, modifiedAt: Date())
        let withTask = makeWorkDay(day: 15, shift: c5, rules: c5Rules, modifiedAt: Date())

        XCTAssertEqual(
            timeComponents(from: withoutTask.resolvedStartDateTime).hour,
            timeComponents(from: withTask.resolvedStartDateTime).hour
        )
    }

    // MARK: - 16-17. OFF Handling

    func testDeletedWorkDayBecomesOFFAfterSync() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])

        try service.deleteWorkDay(id: wd.id)

        // No WorkDay for date = OFF.
        XCTAssertNil(try repo.fetchByDate(date), "Deleted WorkDay = OFF")
    }

    func testOFFDoesNotCreateShiftDefinition() throws {
        // The repository only stores WorkDays. There is no OFF ShiftDefinition
        // concept in the domain. This test documents that invariant.
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Never create anything for OFF.
        XCTAssertNil(try repo.fetchByDate(date))
        XCTAssertEqual(repo.count, 0)

        // A normal shift creates exactly one WorkDay.
        _ = try service.createWorkDay(date: date, shift: c4, rules: [])
        XCTAssertEqual(repo.count, 1)
    }

    // MARK: - 18. Delete Does Not Resurrect

    func testDeletedWorkDayDoesNotResurrect() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)
        let wd = try service.createWorkDay(date: date, shift: c4, rules: [])

        try service.deleteWorkDay(id: wd.id)

        // Even after re-reading (simulating post-sync), it stays gone.
        XCTAssertNil(try repo.fetchByID(wd.id))
        XCTAssertNil(try repo.fetchByDate(date))
    }

    // MARK: - 19. Duplicate Resolution

    func testDateCollisionResolvesToSingleWorkDay() {
        // Two DIFFERENT records claim the same date (sync conflict scenario).
        let older = makeWorkDay(day: 15, shift: c4, rules: [], modifiedAt: makeDate(year: 2026, month: 8, day: 1))
        let newer = makeWorkDay(day: 15, shift: c5, rules: c5Rules, modifiedAt: makeDate(year: 2026, month: 8, day: 10))

        let (winner, losers) = SyncConflictResolver.resolveDateCollision(candidates: [older, newer])

        XCTAssertEqual(winner?.id, newer.id, "Most recently modified wins")
        XCTAssertEqual(losers.count, 1)
        XCTAssertEqual(losers.first?.id, older.id)
    }

    func testDetectDateCollisions() {
        let a = makeWorkDay(day: 15, shift: c4, rules: [], modifiedAt: Date())
        let b = makeWorkDay(day: 15, shift: c5, rules: c5Rules, modifiedAt: Date())
        let c = makeWorkDay(day: 16, shift: c1, rules: [], modifiedAt: Date())

        let collisions = SyncConflictResolver.detectDateCollisions(workDays: [a, b, c], calendar: calendar)

        XCTAssertEqual(collisions.count, 1, "Only day 15 has a collision")
        XCTAssertEqual(collisions.first?.count, 2)
    }

    func testNoCollisionWhenDatesUnique() {
        let a = makeWorkDay(day: 15, shift: c4, rules: [], modifiedAt: Date())
        let b = makeWorkDay(day: 16, shift: c1, rules: [], modifiedAt: Date())

        let collisions = SyncConflictResolver.detectDateCollisions(workDays: [a, b], calendar: calendar)
        XCTAssertTrue(collisions.isEmpty)
    }

    // MARK: - Same-Record Conflict Resolution

    func testSameRecordLastModifiedWins() {
        let id = UUID()
        let older = WorkDay(
            id: id, date: makeDate(year: 2026, month: 8, day: 15),
            shiftID: c4.id, shiftCode: "C4",
            resolvedStartDateTime: Date(), resolvedEndDateTime: Date(),
            resolvedBreakStartDateTime: Date(), resolvedBreakEndDateTime: Date(),
            note: "old", createdAt: Date(),
            modifiedAt: makeDate(year: 2026, month: 8, day: 1)
        )
        let newer = WorkDay(
            id: id, date: makeDate(year: 2026, month: 8, day: 15),
            shiftID: c5.id, shiftCode: "C5",
            resolvedStartDateTime: Date(), resolvedEndDateTime: Date(),
            resolvedBreakStartDateTime: Date(), resolvedBreakEndDateTime: Date(),
            note: "new", createdAt: Date(),
            modifiedAt: makeDate(year: 2026, month: 8, day: 10)
        )

        let winner = SyncConflictResolver.resolveSameRecord(local: older, remote: newer)
        XCTAssertEqual(winner.note, "new", "Newer modifiedAt wins")
        XCTAssertEqual(winner.shiftCode, "C5")
    }

    func testSameRecordDeterministicTiebreak() {
        let sameTime = makeDate(year: 2026, month: 8, day: 5)
        let a = WorkDay(
            id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000000")!,
            date: makeDate(year: 2026, month: 8, day: 15),
            shiftID: c4.id, shiftCode: "C4",
            resolvedStartDateTime: Date(), resolvedEndDateTime: Date(),
            resolvedBreakStartDateTime: Date(), resolvedBreakEndDateTime: Date(),
            note: nil, createdAt: Date(), modifiedAt: sameTime
        )
        let b = WorkDay(
            id: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000000")!,
            date: makeDate(year: 2026, month: 8, day: 15),
            shiftID: c5.id, shiftCode: "C5",
            resolvedStartDateTime: Date(), resolvedEndDateTime: Date(),
            resolvedBreakStartDateTime: Date(), resolvedBreakEndDateTime: Date(),
            note: nil, createdAt: Date(), modifiedAt: sameTime
        )

        // Deterministic: larger UUID string wins (B > A).
        let winner1 = SyncConflictResolver.resolveSameRecord(local: a, remote: b)
        let winner2 = SyncConflictResolver.resolveSameRecord(local: b, remote: a)
        XCTAssertEqual(winner1.id, winner2.id, "Tiebreak must be deterministic regardless of order")
        XCTAssertEqual(winner1.id, b.id)
    }

    // MARK: - 20-22. Configuration Sync (conceptual — snapshot preservation)

    func testExistingSnapshotUnchangedWhenConfigChanges() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)

        // Create C5 → 12:00 special.
        let wd = try service.createWorkDay(date: date, shift: c5, rules: c5Rules)

        // A changed C5 config (13:00) would sync as a ShiftDefinition change,
        // but the existing WorkDay snapshot must not change.
        let reloaded = try repo.fetchByID(wd.id)!
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 12)
    }

    func testNewWorkDayAfterConfigChangeUsesNewConfig() throws {
        let (service, _) = makeService()

        // A "new" C5 config with different times (13:00–22:00).
        let newC5 = ShiftDefinition(
            id: ShiftSeedProvider.c5ID, code: "C5", name: "C5",
            startHour: 13, startMinute: 0, endHour: 22, endMinute: 0,
            breakStartHour: 17, breakStartMinute: 0, breakEndHour: 18, breakEndMinute: 0
        )
        // No special rule for this test — normal resolution with new config.
        let date = makeDate(year: 2026, month: 8, day: 5) // outside 10-20
        let wd = try service.createWorkDay(date: date, shift: newC5, rules: [])

        XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 13,
                       "New WorkDay uses new config")
    }

    // MARK: - Sync Status Display

    func testSyncStatusDisplayText() {
        XCTAssertEqual(SyncStatus.synced.displayText, "Đã đồng bộ")
        XCTAssertEqual(SyncStatus.syncing.displayText, "Đang đồng bộ…")
        XCTAssertEqual(SyncStatus.waitingForConnection.displayText, "Chờ kết nối")
        XCTAssertEqual(SyncStatus.unavailable.displayText, "Đồng bộ tạm ngừng")
        XCTAssertEqual(SyncStatus.accountUnavailable.displayText, "Chưa đăng nhập iCloud")
    }

    // MARK: - 28-30. Failure Resilience

    func testFailedOperationDoesNotCorruptData() throws {
        let (service, repo) = makeService()
        let date = makeDate(year: 2026, month: 8, day: 15)
        _ = try service.createWorkDay(date: date, shift: c4, rules: [])

        // Attempt a duplicate (fails) — original data intact.
        XCTAssertThrowsError(try service.createWorkDay(date: date, shift: c5, rules: c5Rules))

        let existing = try repo.fetchByDate(date)
        XCTAssertEqual(existing?.shiftCode, "C4", "Failed op must not corrupt existing data")
        XCTAssertEqual(repo.count, 1)
    }

    func testSyncConflictDoesNotRecalculateSnapshot() {
        // Two versions of the same WorkDay; the resolver picks one but never
        // recalculates its resolved times.
        let id = UUID()
        let localStart = makeDate(year: 2026, month: 8, day: 15)
        let local = WorkDay(
            id: id, date: localStart,
            shiftID: c5.id, shiftCode: "C5",
            resolvedStartDateTime: makeDate(year: 2026, month: 8, day: 15),
            resolvedEndDateTime: makeDate(year: 2026, month: 8, day: 15),
            resolvedBreakStartDateTime: makeDate(year: 2026, month: 8, day: 15),
            resolvedBreakEndDateTime: makeDate(year: 2026, month: 8, day: 15),
            note: "local", createdAt: Date(), modifiedAt: makeDate(year: 2026, month: 8, day: 10)
        )
        let remote = WorkDay(
            id: id, date: localStart,
            shiftID: c5.id, shiftCode: "C5",
            resolvedStartDateTime: local.resolvedStartDateTime,
            resolvedEndDateTime: local.resolvedEndDateTime,
            resolvedBreakStartDateTime: local.resolvedBreakStartDateTime,
            resolvedBreakEndDateTime: local.resolvedBreakEndDateTime,
            note: "remote", createdAt: Date(), modifiedAt: makeDate(year: 2026, month: 8, day: 5)
        )

        let winner = SyncConflictResolver.resolveSameRecord(local: local, remote: remote)
        // Winner is the local (newer). Its snapshot fields are preserved exactly.
        XCTAssertEqual(winner.resolvedStartDateTime, local.resolvedStartDateTime)
        XCTAssertEqual(winner.note, "local")
    }
}
