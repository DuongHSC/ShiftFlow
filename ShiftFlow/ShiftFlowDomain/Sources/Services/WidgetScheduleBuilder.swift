// ShiftFlow — Domain Layer
// Services/WidgetScheduleBuilder.swift
//
// TASK-WIDGET-001: Builds widget-safe schedule snapshots from WorkDay data.
//
// This is the pure, testable core of the widget data pipeline.
// It reads WorkDay snapshots (already resolved by ShiftResolver) and
// packages them into WidgetScheduleSnapshot for the App Group.
//
// CRITICAL RULES:
// - NEVER calculates shift times. Reads WorkDay.resolved* values only.
// - No C5 / ScheduleRule logic here.
// - OFF = absence of WorkDay (nil today entry).
// - Note text is NOT included in widget data (only hasNote indicator).

import Foundation

/// Builds `WidgetScheduleSnapshot` from WorkDay records.
///
/// Pure and deterministic — depends only on the provided WorkDays and a reference date.
public enum WidgetScheduleBuilder {

    /// Default number of upcoming days to include in the Large widget.
    public static let upcomingDayCount = 5

    /// Future search window for finding the next shift (days).
    public static let nextShiftSearchWindowDays = 90

    /// Builds a widget snapshot from a set of WorkDays.
    ///
    /// - Parameters:
    ///   - workDays: All available WorkDays (should cover today + upcoming range).
    ///   - referenceDate: The "today" reference (defaults to now).
    ///   - taskWorkDayIDs: IDs of WorkDays that have an associated task (for hasTask indicator).
    ///   - calendar: Calendar for date operations.
    /// - Returns: A widget-safe snapshot.
    public static func build(
        workDays: [WorkDay],
        referenceDate: Date = Date(),
        taskWorkDayIDs: Set<UUID> = [],
        calendar: Calendar = .current
    ) -> WidgetScheduleSnapshot {
        let today = calendar.startOfDay(for: referenceDate)

        // Sort by date ascending for deterministic processing.
        let sorted = workDays.sorted { $0.date < $1.date }

        // Today entry (nil = OFF).
        let todayWorkDay = sorted.first { calendar.isDate($0.date, inSameDayAs: today) }
        let todayEntry = todayWorkDay.map {
            WidgetDayEntry(from: $0, hasTask: taskWorkDayIDs.contains($0.id))
        }

        // Next shift: first WorkDay with date > today (within search window).
        let searchEnd = calendar.date(byAdding: .day, value: nextShiftSearchWindowDays, to: today)!
        let nextWorkDay = sorted.first { workDay in
            let day = calendar.startOfDay(for: workDay.date)
            return day > today && day <= searchEnd
        }
        let nextEntry = nextWorkDay.map {
            WidgetDayEntry(from: $0, hasTask: taskWorkDayIDs.contains($0.id))
        }

        // Upcoming: today + next N days for the Large widget.
        let upcomingEnd = calendar.date(byAdding: .day, value: upcomingDayCount, to: today)!
        let upcomingEntries = sorted
            .filter { workDay in
                let day = calendar.startOfDay(for: workDay.date)
                return day >= today && day <= upcomingEnd
            }
            .map { WidgetDayEntry(from: $0, hasTask: taskWorkDayIDs.contains($0.id)) }

        return WidgetScheduleSnapshot(
            today: todayEntry,
            nextShift: nextEntry,
            upcoming: upcomingEntries,
            generatedAt: referenceDate
        )
    }
}
