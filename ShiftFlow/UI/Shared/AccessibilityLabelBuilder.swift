// ShiftFlow — UI Layer
// Shared/AccessibilityLabelBuilder.swift
//
// TASK-POLISH-001: Centralized, consistent accessibility label construction.
//
// All calendar views should build accessibility labels through this helper
// so VoiceOver descriptions are consistent and always include the shift code
// text (never color-only).

import Foundation
import ShiftFlowDomain

/// Builds consistent Vietnamese accessibility labels for schedule elements.
enum AccessibilityLabelBuilder {

    private static let calendar = Calendar.current

    /// Full accessibility label for a WorkDay (or OFF) on a date.
    ///
    /// Example: "Thứ 4, ngày 19 tháng 8, ca C4, 08:30 đến 18:00, nghỉ 12:30 đến 13:30"
    /// OFF:     "Thứ 4, ngày 19 tháng 8, nghỉ"
    static func dayLabel(
        date: Date,
        workDay: WorkDay?,
        includeBreak: Bool = false,
        includeNote: Bool = false,
        calendar: Calendar = .current
    ) -> String {
        let weekday = WeekdayFormatter.fullName(for: date, calendar: calendar)
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)

        var parts: [String] = ["\(weekday), ngày \(day) tháng \(month)"]

        if let wd = workDay {
            parts.append("ca \(wd.shiftCode)")
            parts.append(timePhrase(start: wd.resolvedStartDateTime, end: wd.resolvedEndDateTime, calendar: calendar))

            if includeBreak {
                parts.append("nghỉ \(timePhrase(start: wd.resolvedBreakStartDateTime, end: wd.resolvedBreakEndDateTime, calendar: calendar))")
            }
            if includeNote, let note = wd.note, !note.isEmpty {
                parts.append("ghi chú: \(note)")
            }
        } else {
            parts.append("OFF")
        }

        return parts.joined(separator: ", ")
    }

    /// Accessibility label for the Next Shift element.
    static func nextShiftLabel(_ workDay: WorkDay?, calendar: Calendar = .current) -> String {
        guard let wd = workDay else {
            return "Không có ca làm việc sắp tới"
        }
        let weekday = WeekdayFormatter.fullName(for: wd.date, calendar: calendar)
        return "Ca tiếp theo: \(weekday), ca \(wd.shiftCode), \(timePhrase(start: wd.resolvedStartDateTime, end: wd.resolvedEndDateTime, calendar: calendar))"
    }

    // MARK: - Private

    /// Builds a spoken time-range phrase "HH:mm đến HH:mm".
    private static func timePhrase(start: Date, end: Date, calendar: Calendar) -> String {
        "\(TimeFormatter.format(start)) đến \(TimeFormatter.format(end))"
    }
}
