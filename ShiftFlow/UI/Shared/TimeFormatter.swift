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

    /// Formats a Date as "HH:mm" (e.g., "12:00").
    public static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }

    /// Formats a time range as "HH:mm → HH:mm" (e.g., "12:00 → 21:30").
    public static func formatRange(start: Date, end: Date) -> String {
        "\(format(start)) → \(format(end))"
    }
}
