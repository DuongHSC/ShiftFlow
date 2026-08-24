// ShiftFlow — Widget Extension
// Views/WidgetFormatting.swift
//
// TASK-WIDGET-001: Widget-local formatting helpers.
//
// The Widget target cannot import the app's UI layer, so it uses these
// local helpers. Vietnamese weekday logic mirrors the app convention
// via Foundation Calendar (no hardcoded weekday positions).

import Foundation
import SwiftUI

/// Widget-local formatting helpers.
enum WidgetFormatting {

    // MARK: - Time

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func timeRange(_ start: Date, _ end: Date) -> String {
        "\(time(start)) → \(time(end))"
    }

    // MARK: - Vietnamese Weekday

    static func weekdayFull(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.weekday, from: date) {
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

    static func weekdayShort(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.weekday, from: date) {
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

    // MARK: - Date

    static func shortDate(for date: Date, calendar: Calendar = .current) -> String {
        let d = calendar.component(.day, from: date)
        let m = calendar.component(.month, from: date)
        return String(format: "%02d/%02d", d, m)
    }

    static func fullDate(for date: Date, calendar: Calendar = .current) -> String {
        let d = calendar.component(.day, from: date)
        let m = calendar.component(.month, from: date)
        let y = calendar.component(.year, from: date)
        return String(format: "%02d/%02d/%04d", d, m, y)
    }

    // MARK: - Shift Color (supplementary only — code text always shown)

    static func shiftColor(_ code: String) -> Color {
        switch code.uppercased() {
        case "C5": return .red
        case "C4": return .primary
        case "C3": return .green
        case "C2": return .orange
        case "C1": return .purple
        default: return .secondary
        }
    }

    /// Task indicator color — blue, tasks only, never a shift.
    static let taskColor: Color = .blue
}
