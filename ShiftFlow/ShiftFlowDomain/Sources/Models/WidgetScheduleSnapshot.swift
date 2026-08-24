// ShiftFlow — Domain Layer
// Models/WidgetScheduleSnapshot.swift
//
// TASK-WIDGET-001: Widget-safe schedule snapshot models.
//
// These immutable value types are the data contract between the main app
// (which writes them to the App Group) and the Widget extension (which reads them).
//
// CRITICAL RULES:
// - Widget data is snapshot-style (immutable).
// - Widget NEVER calculates shift times — it displays WorkDay snapshot values.
// - No C5 / ScheduleRule logic in widget data.
// - Task = indicator only. Note text is NOT exposed in widget data (privacy).
// - OFF = absence of a day entry (nil), not a persistent record.

import Foundation

// MARK: - Widget Day Entry

/// A widget-safe representation of a single day's schedule.
///
/// Built from a `WorkDay` snapshot. Contains only display-safe values.
/// Note text is intentionally excluded to avoid exposing private content.
public struct WidgetDayEntry: Equatable, Codable, Sendable {

    /// The calendar date.
    public let date: Date

    /// Shift code (e.g., "C1", "C5").
    public let shiftCode: String

    /// Resolved shift start time (from WorkDay snapshot).
    public let startDateTime: Date

    /// Resolved shift end time (from WorkDay snapshot).
    public let endDateTime: Date

    /// Resolved break start (from WorkDay snapshot).
    public let breakStartDateTime: Date

    /// Resolved break end (from WorkDay snapshot).
    public let breakEndDateTime: Date

    /// Whether this day has an associated task (indicator only, no content leak).
    public let hasTask: Bool

    /// Whether this day has a note (indicator only, note text NOT included).
    public let hasNote: Bool

    public init(
        date: Date,
        shiftCode: String,
        startDateTime: Date,
        endDateTime: Date,
        breakStartDateTime: Date,
        breakEndDateTime: Date,
        hasTask: Bool = false,
        hasNote: Bool = false
    ) {
        self.date = date
        self.shiftCode = shiftCode
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.breakStartDateTime = breakStartDateTime
        self.breakEndDateTime = breakEndDateTime
        self.hasTask = hasTask
        self.hasNote = hasNote
    }
}

// MARK: - Widget Schedule Snapshot

/// The complete widget-safe schedule snapshot shared via App Group.
///
/// Contains today's schedule, the next shift, and upcoming days.
/// This is what the Widget reads to build its timeline.
public struct WidgetScheduleSnapshot: Equatable, Codable, Sendable {

    /// Today's schedule (nil = OFF, no WorkDay for today).
    public let today: WidgetDayEntry?

    /// The next scheduled shift after today (nil = none upcoming).
    public let nextShift: WidgetDayEntry?

    /// Upcoming days (for the Large widget), sorted by date ascending.
    public let upcoming: [WidgetDayEntry]

    /// When this snapshot was generated.
    public let generatedAt: Date

    public init(
        today: WidgetDayEntry?,
        nextShift: WidgetDayEntry?,
        upcoming: [WidgetDayEntry],
        generatedAt: Date = Date()
    ) {
        self.today = today
        self.nextShift = nextShift
        self.upcoming = upcoming
        self.generatedAt = generatedAt
    }

    /// An empty snapshot (used as placeholder/fallback).
    public static let empty = WidgetScheduleSnapshot(
        today: nil,
        nextShift: nil,
        upcoming: [],
        generatedAt: Date(timeIntervalSince1970: 0)
    )
}

// MARK: - WorkDay → WidgetDayEntry Mapping

public extension WidgetDayEntry {

    /// Builds a widget entry from a WorkDay snapshot.
    ///
    /// - Parameters:
    ///   - workDay: The source WorkDay (provides all resolved values).
    ///   - hasTask: Whether the WorkDay has an associated task.
    /// - Returns: A widget-safe entry.
    init(from workDay: WorkDay, hasTask: Bool = false) {
        self.init(
            date: workDay.date,
            shiftCode: workDay.shiftCode,
            startDateTime: workDay.resolvedStartDateTime,
            endDateTime: workDay.resolvedEndDateTime,
            breakStartDateTime: workDay.resolvedBreakStartDateTime,
            breakEndDateTime: workDay.resolvedBreakEndDateTime,
            hasTask: hasTask,
            hasNote: !(workDay.note?.isEmpty ?? true)
        )
    }
}
