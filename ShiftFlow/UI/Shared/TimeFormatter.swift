// ShiftFlow — UI Layer
// Shared/TimeFormatter.swift
//
// TASK-CALENDAR-001: Time display formatting.

import Foundation

/// Formats Date values as time strings for display.
public enum TimeFormatter {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Formats a Date as "HH:mm" (e.g., "12:00") in the current time zone.
    public static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }

    /// Formats a time range as "HH:mm → HH:mm" (e.g., "12:00 → 21:30").
    public static func formatRange(start: Date, end: Date) -> String {
        "\(format(start)) → \(format(end))"
    }

    /// Formats a Date as "HH:mm" using the given calendar's time zone.
    ///
    /// Resolved shift times are computed in a specific calendar/time zone (the
    /// user's local zone). Formatting them with the system time zone (e.g. UTC on
    /// CI) shifts the displayed clock time. Passing the calendar keeps the wall-
    /// clock time consistent with how the shift was resolved.
    public static func format(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        return f.string(from: date)
    }

    /// Formats a time range "HH:mm → HH:mm" using the given calendar's time zone.
    public static func formatRange(start: Date, end: Date, calendar: Calendar) -> String {
        "\(format(start, calendar: calendar)) → \(format(end, calendar: calendar))"
    }
}
