// ShiftFlow — Domain Layer
// Services/WidgetRefreshing.swift
//
// TASK-WIDGET-002: Widget refresh abstraction.
//
// Defines the interface the domain uses to push a rebuilt widget snapshot
// to the platform (App Group + WidgetKit reload). This keeps the domain
// independent of WidgetKit — the concrete implementation lives in the app/widget.
//
// ARCHITECTURE:
// WorkDayService → WidgetRefreshCoordinator → WidgetSnapshotSink → (App Group + WidgetKit)
//
// CRITICAL:
// - Widget refresh is SECONDARY. It must never cause a WorkDay operation to fail.
// - The single source of snapshot conversion is WidgetScheduleBuilder.

import Foundation

/// A sink that receives a rebuilt widget snapshot and persists/reloads it.
///
/// Concrete implementation (in the app) writes to the App Group and requests
/// a WidgetKit reload. The domain depends only on this protocol.
public protocol WidgetSnapshotSink: AnyObject {
    /// Writes the snapshot to shared storage and requests a widget reload.
    /// Implementations MUST NOT throw — failures are handled/logged internally.
    func publish(_ snapshot: WidgetScheduleSnapshot)
}

/// Coordinates rebuilding and publishing the widget snapshot after WorkDay changes.
///
/// This is the ONLY place (besides WidgetScheduleBuilder) responsible for
/// converting application data into widget snapshot data at runtime.
public final class WidgetRefreshCoordinator {

    private let repository: WorkDayRepository
    private let sink: WidgetSnapshotSink
    private let calendar: Calendar

    /// Optional provider of task-associated WorkDay IDs (for hasTask indicator).
    /// Returns the set of WorkDay IDs that currently have a task.
    private let taskWorkDayIDsProvider: () -> Set<UUID>

    public init(
        repository: WorkDayRepository,
        sink: WidgetSnapshotSink,
        taskWorkDayIDsProvider: @escaping () -> Set<UUID> = { [] },
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.sink = sink
        self.taskWorkDayIDsProvider = taskWorkDayIDsProvider
        self.calendar = calendar
    }

    /// Rebuilds the widget snapshot from current WorkDay data and publishes it.
    ///
    /// This is SECONDARY to WorkDay persistence. Any failure while reading
    /// WorkDays is swallowed so it can never affect the primary operation.
    ///
    /// - Parameter referenceDate: The "today" reference (defaults to now).
    public func refresh(referenceDate: Date = Date()) {
        // Read the window needed for the widget: today .. upcoming + next-shift search.
        let today = calendar.startOfDay(for: referenceDate)
        let windowEnd = calendar.date(
            byAdding: .day,
            value: WidgetScheduleBuilder.nextShiftSearchWindowDays,
            to: today
        ) ?? today

        let workDays: [WorkDay]
        do {
            workDays = try repository.fetchByDateRange(from: today, to: windowEnd)
        } catch {
            // Reading failed — do not publish, do not crash.
            // Leave the previous widget snapshot intact.
            return
        }

        let snapshot = WidgetScheduleBuilder.build(
            workDays: workDays,
            referenceDate: referenceDate,
            taskWorkDayIDs: taskWorkDayIDsProvider(),
            calendar: calendar
        )

        // Publish is non-throwing; the sink handles its own failures.
        sink.publish(snapshot)
    }
}
