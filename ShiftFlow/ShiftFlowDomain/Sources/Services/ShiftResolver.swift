// ShiftFlow — Domain Layer
// Services/ShiftResolver.swift
//
// TASK-SHIFT-001: ShiftResolver implementation.
//
// ShiftResolver is the single source of truth for shift schedule resolution.
// It accepts a date, a ShiftDefinition, and applicable ScheduleRules,
// and returns a fully resolved ResolvedShift with concrete date-time values.
//
// Properties:
// - Deterministic: same inputs always produce the same output.
// - Pure: no side effects, no network, no UI dependency.
// - Independent of: SwiftUI, WidgetKit, UserNotifications, CloudKit.
//
// All features requiring working time (Calendar, Today, Reminder, Widget)
// must use this resolver. No feature may implement independent shift calculation.

import Foundation

/// Central schedule-resolution service for ShiftFlow.
///
/// Usage:
/// ```swift
/// let resolved = ShiftResolver.resolve(
///     date: someDate,
///     shift: shiftDefinition,
///     rules: applicableRules
/// )
/// ```
public enum ShiftResolver {

    /// Resolves the concrete schedule for a given date and shift definition.
    ///
    /// The resolver checks active ScheduleRules that match the day-of-month.
    /// If a matching rule exists, its times override the shift definition defaults.
    /// If multiple rules match, the one with the highest priority wins.
    /// If no rules match, the shift definition's default times are used.
    ///
    /// - Parameters:
    ///   - date: The calendar date to resolve (only the date component matters).
    ///   - shift: The ShiftDefinition to resolve.
    ///   - rules: All ScheduleRules associated with this shift (active and inactive).
    ///   - calendar: The calendar to use for date calculations. Defaults to `.current`.
    /// - Returns: A `ResolvedShift` containing concrete date-time values.
    public static func resolve(
        date: Date,
        shift: ShiftDefinition,
        rules: [ScheduleRule],
        calendar: Calendar = .current
    ) -> ResolvedShift {
        let dayOfMonth = calendar.component(.day, from: date)

        // Find the highest-priority active rule that applies to this day.
        let matchingRule = rules
            .filter { $0.applies(toDayOfMonth: dayOfMonth) }
            .sorted { $0.priority > $1.priority }
            .first

        // Determine the effective time components.
        let effectiveStartHour: Int
        let effectiveStartMinute: Int
        let effectiveEndHour: Int
        let effectiveEndMinute: Int
        let effectiveBreakStartHour: Int
        let effectiveBreakStartMinute: Int
        let effectiveBreakEndHour: Int
        let effectiveBreakEndMinute: Int

        if let rule = matchingRule {
            effectiveStartHour = rule.startHour
            effectiveStartMinute = rule.startMinute
            effectiveEndHour = rule.endHour
            effectiveEndMinute = rule.endMinute
            effectiveBreakStartHour = rule.breakStartHour
            effectiveBreakStartMinute = rule.breakStartMinute
            effectiveBreakEndHour = rule.breakEndHour
            effectiveBreakEndMinute = rule.breakEndMinute
        } else {
            effectiveStartHour = shift.startHour
            effectiveStartMinute = shift.startMinute
            effectiveEndHour = shift.endHour
            effectiveEndMinute = shift.endMinute
            effectiveBreakStartHour = shift.breakStartHour
            effectiveBreakStartMinute = shift.breakStartMinute
            effectiveBreakEndHour = shift.breakEndHour
            effectiveBreakEndMinute = shift.breakEndMinute
        }

        // Build concrete date-time values on the given calendar date.
        let startDateTime = Self.makeDateTime(
            date: date, hour: effectiveStartHour, minute: effectiveStartMinute, calendar: calendar
        )
        let endDateTime = Self.makeDateTime(
            date: date, hour: effectiveEndHour, minute: effectiveEndMinute, calendar: calendar
        )
        let breakStartDateTime = Self.makeDateTime(
            date: date, hour: effectiveBreakStartHour, minute: effectiveBreakStartMinute, calendar: calendar
        )
        let breakEndDateTime = Self.makeDateTime(
            date: date, hour: effectiveBreakEndHour, minute: effectiveBreakEndMinute, calendar: calendar
        )

        return ResolvedShift(
            shiftID: shift.id,
            shiftCode: shift.code,
            date: date,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            breakStartDateTime: breakStartDateTime,
            breakEndDateTime: breakEndDateTime
        )
    }

    // MARK: - Private Helpers

    /// Creates a Date with a specific hour and minute on the same calendar day as `date`.
    private static func makeDateTime(
        date: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }
}
