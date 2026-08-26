// ShiftFlow — Tests
// PersistenceRoundTripTests.swift
//
// TASK-QA-AUTOMATION-002 (QA-20): On-disk SwiftData persistence round-trip.
//
// Verifies that WorkDays (incl. resolved snapshot), task assignments, notes,
// and shift/rule/task CONFIGURATION persist across a FRESH ModelContainer /
// ModelContext opened from the SAME on-disk store URL — i.e. the data survives
// tearing down and rebuilding the persistence stack. Also verifies seed
// idempotency on the "second launch" (reopen + seed → no C1–C5 / MW duplicates).
//
// SCOPE / DISTINCTIONS (intentional):
// - This verifies persistence across a fresh ModelContainer/context using an
//   on-disk local SwiftData store and the REAL production persistence stack
//   (PersistenceConfiguration.schema + SwiftData repositories/stores/services).
// - It does NOT claim: OS process-level app relaunch, signed-device persistence,
//   CloudKit persistence, or multi-device sync (those require device/iCloud).
//
// This file uses SwiftData + app-layer persistence types, so it imports the app
// module and is compiled by the app-hosted `ShiftFlowTests` Xcode target. It is
// excluded from the standalone `ShiftFlowDomain` SPM test target (see Package.swift),
// consistent with the other app-dependent test files.

import XCTest
import SwiftData
@testable import ShiftFlowDomain
@testable import ShiftFlow

final class PersistenceRoundTripTests: XCTestCase {

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

    /// A unique temporary on-disk store URL for this test run.
    private func makeTempStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftFlowPersistenceRoundTrip-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    /// Builds a ModelContainer backed by the given on-disk URL, using the
    /// PRODUCTION schema and a local (non-CloudKit) configuration.
    private func makeContainer(url: URL) throws -> ModelContainer {
        let config = ModelConfiguration(schema: PersistenceConfiguration.schema, url: url)
        return try ModelContainer(for: PersistenceConfiguration.schema, configurations: [config])
    }

    /// Removes the temporary store directory (and its sidecar files).
    private func cleanUp(_ url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Full round trip

    func testWorkDayTaskNoteAndConfigurationPersistAcrossFreshContainer() throws {
        let url = makeTempStoreURL()
        defer { cleanUp(url) }

        let date = makeDate(year: 2026, month: 8, day: 15)
        var workDayID = UUID()

        // ---- Session 1: write through the real persistence stack ----
        do {
            let container = try makeContainer(url: url)
            let context = ModelContext(container)

            let configStore = SwiftDataShiftConfigurationStore(modelContext: context)
            let configService = ShiftConfigurationService(store: configStore)
            configService.seedIfNeeded()                      // seed C1–C5 + C5 rule

            // Edit a shift config (must persist).
            let c1 = try XCTUnwrap(configService.shift(withCode: "C1"))
            try configService.updateShift(c1.withEdits(startHour: 5, startMinute: 0))

            let taskStore = SwiftDataTaskStore(modelContext: context)
            let taskService = TaskService(store: taskStore)
            taskService.seedIfNeeded()                        // seed MW
            let ticket = try taskService.createTask(code: "Ticket", name: "Ticket") // custom task config

            let repo = SwiftDataWorkDayRepository(modelContext: context, calendar: calendar)
            let wdService = WorkDayService(repository: repo, calendar: calendar)

            // Create a C5 WorkDay on day 15 (special → 12:00–21:30) with a note.
            let (c5, rules) = try XCTUnwrap(configService.lookup("C5"))
            let wd = try wdService.createWorkDay(date: date, shift: c5, rules: rules, note: "Trực MW")
            workDayID = wd.id
            XCTAssertEqual(timeComponents(from: wd.resolvedStartDateTime).hour, 12)

            // Assign MW + Ticket to the WorkDay.
            let mw = try XCTUnwrap(taskService.task(withCode: "MW"))
            try taskService.addTask(taskDefinitionID: mw.id, toWorkDay: wd.id)
            try taskService.addTask(taskDefinitionID: ticket.id, toWorkDay: wd.id)

            // Explicit commit through the real save path.
            try context.save()

            // Tear down session 1 (drop references so the stack is released).
            _ = configService; _ = taskService; _ = wdService
        }

        // ---- Session 2: reopen a NEW container from the SAME url ----
        let container2 = try makeContainer(url: url)
        let context2 = ModelContext(container2)

        let configStore2 = SwiftDataShiftConfigurationStore(modelContext: context2)
        let configService2 = ShiftConfigurationService(store: configStore2)
        let taskStore2 = SwiftDataTaskStore(modelContext: context2)
        let taskService2 = TaskService(store: taskStore2)
        let repo2 = SwiftDataWorkDayRepository(modelContext: context2, calendar: calendar)

        // 9. WorkDay present and correct.
        let reloaded = try XCTUnwrap(try repo2.fetchByID(workDayID), "WorkDay must persist across fresh container")
        XCTAssertEqual(reloaded.shiftCode, "C5")
        XCTAssertEqual(reloaded.note, "Trực MW")               // 11. note persisted & independent
        // 10. historical snapshot fields unchanged (C5 day 15 special = 12:00 → 21:30).
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).hour, 12)
        XCTAssertEqual(timeComponents(from: reloaded.resolvedStartDateTime).minute, 0)
        XCTAssertEqual(timeComponents(from: reloaded.resolvedEndDateTime).hour, 21)
        XCTAssertEqual(timeComponents(from: reloaded.resolvedEndDateTime).minute, 30)

        // Fetch-by-date also resolves the same WorkDay.
        let byDate = try XCTUnwrap(try repo2.fetchByDate(date))
        XCTAssertEqual(byDate.id, workDayID)

        // 11. Task assignments persisted, independent of the note.
        let codes = Set(taskService2.tasks(forWorkDay: workDayID).map { $0.code })
        XCTAssertEqual(codes, ["MW", "Ticket"])
        XCTAssertEqual(reloaded.note, "Trực MW")               // note still ONLY the note

        // 12. Shift/rule/task configuration persisted.
        XCTAssertEqual(configService2.allShifts().count, 5)
        XCTAssertEqual(try XCTUnwrap(configService2.shift(withCode: "C1")).startHour, 5) // edited config survived
        XCTAssertNotNil(configService2.lookup("C5")?.rules.first)                        // C5 rule survived
        XCTAssertNotNil(taskService2.task(withCode: "Ticket"))                           // custom task survived
        XCTAssertNotNil(taskService2.task(withCode: "MW"))
    }

    // MARK: - Seed idempotency across relaunch (second launch)

    func testSeedIsIdempotentAcrossFreshContainer() throws {
        let url = makeTempStoreURL()
        defer { cleanUp(url) }

        // ---- Session 1: first launch seeds defaults ----
        do {
            let container = try makeContainer(url: url)
            let context = ModelContext(container)
            let configService = ShiftConfigurationService(store: SwiftDataShiftConfigurationStore(modelContext: context))
            let taskService = TaskService(store: SwiftDataTaskStore(modelContext: context))
            configService.seedIfNeeded()
            taskService.seedIfNeeded()
            try context.save()
            XCTAssertEqual(configService.allShifts().count, 5)
            XCTAssertEqual(taskService.allTasks().filter { $0.code == "MW" }.count, 1)
        }

        // ---- Session 2: reopen SAME store, run the normal seed path again ----
        let container2 = try makeContainer(url: url)
        let context2 = ModelContext(container2)
        let configService2 = ShiftConfigurationService(store: SwiftDataShiftConfigurationStore(modelContext: context2))
        let taskService2 = TaskService(store: SwiftDataTaskStore(modelContext: context2))
        configService2.seedIfNeeded()   // second-launch seed must be idempotent
        taskService2.seedIfNeeded()

        // C1–C5 not duplicated.
        XCTAssertEqual(configService2.allShifts().count, 5)
        for code in ["C1", "C2", "C3", "C4", "C5"] {
            XCTAssertEqual(configService2.allShifts().filter { $0.code == code }.count, 1, "\(code) must not be duplicated")
        }
        // C5 special rule not duplicated.
        XCTAssertEqual(configService2.allRules().count, 1)
        // MW not duplicated.
        XCTAssertEqual(taskService2.allTasks().filter { $0.code == "MW" }.count, 1)
    }
}
