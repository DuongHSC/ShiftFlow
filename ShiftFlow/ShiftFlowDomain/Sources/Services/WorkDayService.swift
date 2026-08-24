// ShiftFlow — Domain Layer
// Services/WorkDayService.swift
//
// TASK-WORKDAY-001: WorkDay domain service.
//
// Coordinates WorkDay CRUD operations with ShiftResolver.
// Enforces the historical snapshot strategy:
// - Creation: resolve + snapshot
// - Shift change: re-resolve + update snapshot
// - Config change: NO automatic recalculation
//
// This service is the approved path for WorkDay mutations.
// It does NOT depend on SwiftUI, WidgetKit, or CloudKit.

import Foundation

/// Domain service for WorkDay operations.
///
/// All WorkDay creation and modification flows through this service
/// to ensure the historical snapshot strategy is maintained.
///
/// Usage:
/// ```swift
/// let service = WorkDayService(repository: repo)
/// let workDay = try service.createWorkDay(
///     date: someDate,
///     shift: shiftDef,
///     rules: rules
/// )
/// ```
public final class WorkDayService {

    private let repository: WorkDayRepository
    private let calendar: Calendar

    /// Optional coordinator that refreshes widget data after WorkDay changes.
    /// TASK-WIDGET-002: Widget refresh is SECONDARY — it runs only after
    /// successful persistence and never affects the WorkDay operation result.
    private let widgetRefresher: WidgetRefreshCoordinator?

    public init(
        repository: WorkDayRepository,
        calendar: Calendar = .current,
        widgetRefresher: WidgetRefreshCoordinator? = nil
    ) {
        self.repository = repository
        self.calendar = calendar
        self.widgetRefresher = widgetRefresher
    }

    /// Refreshes widget data after a successful WorkDay mutation.
    /// Non-throwing: any widget failure is contained within the coordinator/sink.
    private func refreshWidgetIfNeeded() {
        widgetRefresher?.refresh()
    }

    // MARK: - Create

    /// Creates a new WorkDay for the given date with the specified shift.
    ///
    /// Flow:
    /// 1. Check if a WorkDay already exists for this date.
    /// 2. If duplicate: throw `duplicateDate` error.
    /// 3. Resolve the shift schedule using ShiftResolver.
    /// 4. Create WorkDay with the resolved snapshot.
    /// 5. Persist.
    ///
    /// - Parameters:
    ///   - date: The calendar date for the WorkDay.
    ///   - shift: The ShiftDefinition to assign.
    ///   - rules: ScheduleRules applicable to this shift.
    ///   - note: Optional note text.
    /// - Returns: The created WorkDay with resolved snapshot.
    /// - Throws: `WorkDayRepositoryError.duplicateDate` if a WorkDay exists for this date.
    public func createWorkDay(
        date: Date,
        shift: ShiftDefinition,
        rules: [ScheduleRule],
        note: String? = nil
    ) throws -> WorkDay {
        // Normalize date to start of day for consistent comparison.
        let normalizedDate = normalizeDate(date)

        // Check for existing WorkDay on this date.
        if let existing = try repository.fetchByDate(normalizedDate) {
            throw WorkDayRepositoryError.duplicateDate(existing.date)
        }

        // Resolve schedule using ShiftResolver (single source of truth).
        let resolved = ShiftResolver.resolve(
            date: normalizedDate,
            shift: shift,
            rules: rules,
            calendar: calendar
        )

        // Create WorkDay with historical snapshot.
        let now = Date()
        let workDay = WorkDay(
            date: normalizedDate,
            resolvedShift: resolved,
            note: note,
            createdAt: now,
            modifiedAt: now
        )

        // Persist (primary operation).
        try repository.create(workDay)

        // Refresh widget (secondary — cannot fail the create).
        refreshWidgetIfNeeded()

        return workDay
    }

    // MARK: - Read

    /// Fetches a WorkDay by its ID.
    public func fetchWorkDay(id: UUID) throws -> WorkDay? {
        try repository.fetchByID(id)
    }

    /// Fetches the WorkDay for a specific calendar date.
    public func fetchWorkDay(date: Date) throws -> WorkDay? {
        let normalizedDate = normalizeDate(date)
        return try repository.fetchByDate(normalizedDate)
    }

    /// Fetches all WorkDays within a date range (inclusive).
    public func fetchWorkDays(from startDate: Date, to endDate: Date) throws -> [WorkDay] {
        let start = normalizeDate(startDate)
        let end = normalizeDate(endDate)
        return try repository.fetchByDateRange(from: start, to: end)
    }

    // MARK: - Update (Shift Change)

    /// Changes the shift assigned to an existing WorkDay.
    ///
    /// This is an EXPLICIT shift change — the only approved path for
    /// modifying a WorkDay's resolved snapshot after creation.
    ///
    /// Flow:
    /// 1. Fetch existing WorkDay.
    /// 2. Resolve the NEW shift for the WorkDay's date.
    /// 3. Replace the snapshot with new resolved values.
    /// 4. Persist the update.
    ///
    /// - Parameters:
    ///   - workDayID: The ID of the WorkDay to update.
    ///   - newShift: The new ShiftDefinition to assign.
    ///   - rules: ScheduleRules applicable to the new shift.
    /// - Returns: The updated WorkDay with new snapshot.
    /// - Throws: `WorkDayRepositoryError.notFound` if the WorkDay doesn't exist.
    public func changeShift(
        workDayID: UUID,
        newShift: ShiftDefinition,
        rules: [ScheduleRule]
    ) throws -> WorkDay {
        guard let existing = try repository.fetchByID(workDayID) else {
            throw WorkDayRepositoryError.notFound(workDayID)
        }

        // Resolve new shift for the WorkDay's existing date.
        let resolved = ShiftResolver.resolve(
            date: existing.date,
            shift: newShift,
            rules: rules,
            calendar: calendar
        )

        // Update snapshot (this is the explicit edit path).
        let updated = existing.withUpdatedShift(resolved)

        // Persist (primary operation).
        try repository.update(updated)

        // Refresh widget (secondary).
        refreshWidgetIfNeeded()

        return updated
    }

    // MARK: - Update (Note)

    /// Updates the note on an existing WorkDay.
    /// This does NOT modify the resolved snapshot.
    public func updateNote(workDayID: UUID, note: String?) throws -> WorkDay {
        guard let existing = try repository.fetchByID(workDayID) else {
            throw WorkDayRepositoryError.notFound(workDayID)
        }

        let updated = existing.withUpdatedNote(note)
        try repository.update(updated)

        // Refresh widget so the hasNote indicator stays accurate.
        // Note text is NOT exposed in widget data.
        refreshWidgetIfNeeded()

        return updated
    }

    // MARK: - Delete

    /// Deletes a WorkDay.
    ///
    /// Note: Reminder cancellation is NOT handled here.
    /// That responsibility belongs to the Notifications layer (TASK-REMINDER-001).
    public func deleteWorkDay(id: UUID) throws {
        // Persist deletion (primary operation).
        try repository.delete(id)

        // Refresh widget (secondary — only after successful delete).
        refreshWidgetIfNeeded()
    }

    // MARK: - Private Helpers

    /// Normalizes a date to the start of day for consistent date comparison.
    private func normalizeDate(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
