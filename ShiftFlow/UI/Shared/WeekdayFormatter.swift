// ShiftFlow — UI Layer
// Shared/WeekdayFormatter.swift
//
// TASK-CALENDAR-001: Vietnamese weekday display helper.
//
// Provides localized Vietnamese weekday names.
// Uses Foundation Calendar — does NOT hardcode weekday positions.

import Foundation

/// Provides Vietnamese weekday formatting for Calendar display.
public enum WeekdayFormatter {

    /// Full Vietnamese weekday names.
    /// weekday 1 = Sunday (Gregorian), weekday 2 = Monday, etc.
    public static func fullName(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Chủ nhật"
        case 2: return "Thứ 2"
        case 3: return "Thứ 3"
        case 4: return "Thứ 4"
        case 5: return "Thứ 5"
        case 6: return "Thứ 6"
        case 7: return "Thứ 7"
        default: return ""
        }
    }

    /// Short Vietnamese weekday names (for compact displays).
    public static func shortName(for weekday: Int) -> String {
        switch weekday {
        case 1: return "CN"
        case 2: return "T2"
        case 3: return "T3"
        case 4: return "T4"
        case 5: return "T5"
        case 6: return "T6"
        case 7: return "T7"
        default: return ""
        }
    }

    /// Full weekday name from a Date.
    public static func fullName(for date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return fullName(for: weekday)
    }

    /// Short weekday name from a Date.
    public static func shortName(for date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return shortName(for: weekday)
    }

    /// Ordered short weekday names for a Monday-first calendar header.
    public static let mondayFirstShortNames: [String] = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
}
