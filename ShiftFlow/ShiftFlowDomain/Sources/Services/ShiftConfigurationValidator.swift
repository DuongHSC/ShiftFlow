// ShiftFlow — Domain Layer
// Services/ShiftConfigurationValidator.swift
//
// TASK-SETTINGS-001: Pure validation for shift/rule configuration edits.
//
// Validates ShiftDefinition and ScheduleRule edits BEFORE they are stored.
// Contains NO shift-resolution logic — validation only.

import Foundation

/// Errors produced when a shift/rule configuration edit is invalid.
public enum ShiftConfigurationError: Error, Equatable {
    /// start time is not before end time.
    case startNotBeforeEnd
    /// break start is not before break end.
    case breakStartNotBeforeBreakEnd
    /// break interval is not fully inside the working interval.
    case breakOutsideWorkingInterval
    /// display name is empty.
    case emptyName
    /// a shift with the same code already exists (duplicate code).
    case duplicateCode(String)
    /// the shift/rule to edit was not found.
    case notFound
    /// schedule rule day range is invalid (must be 1...31 and start <= end).
    case invalidDayRange
}

/// Validates shift and schedule-rule configuration edits.
public enum ShiftConfigurationValidator {

    /// Minutes-from-midnight helper for a (hour, minute) pair.
    static func minutes(_ hour: Int, _ minute: Int) -> Int {
        hour * 60 + minute
    }

    /// Validates a ShiftDefinition's time/name fields.
    ///
    /// Rules:
    /// - start < end
    /// - break start < break end
    /// - break interval fully within [start, end]
    /// - name not empty
    ///
    /// - Throws: `ShiftConfigurationError` on the first failing rule.
    public static func validateDefinition(_ def: ShiftDefinition) throws {
        let start = minutes(def.startHour, def.startMinute)
        let end = minutes(def.endHour, def.endMinute)
        let bStart = minutes(def.breakStartHour, def.breakStartMinute)
        let bEnd = minutes(def.breakEndHour, def.breakEndMinute)

        if def.name.trimmingCharacters(in: .whitespaces).isEmpty {
            throw ShiftConfigurationError.emptyName
        }
        if start >= end {
            throw ShiftConfigurationError.startNotBeforeEnd
        }
        if bStart >= bEnd {
            throw ShiftConfigurationError.breakStartNotBeforeBreakEnd
        }
        if bStart < start || bEnd > end {
            throw ShiftConfigurationError.breakOutsideWorkingInterval
        }
    }

    /// Validates a ScheduleRule's day range and time/break fields.
    ///
    /// Rules:
    /// - 1 <= startDay <= endDay <= 31
    /// - start < end
    /// - break start < break end
    /// - break within working interval
    public static func validateRule(_ rule: ScheduleRule) throws {
        if rule.startDayOfMonth < 1
            || rule.endDayOfMonth > 31
            || rule.startDayOfMonth > rule.endDayOfMonth {
            throw ShiftConfigurationError.invalidDayRange
        }

        let start = minutes(rule.startHour, rule.startMinute)
        let end = minutes(rule.endHour, rule.endMinute)
        let bStart = minutes(rule.breakStartHour, rule.breakStartMinute)
        let bEnd = minutes(rule.breakEndHour, rule.breakEndMinute)

        if start >= end {
            throw ShiftConfigurationError.startNotBeforeEnd
        }
        if bStart >= bEnd {
            throw ShiftConfigurationError.breakStartNotBeforeBreakEnd
        }
        if bStart < start || bEnd > end {
            throw ShiftConfigurationError.breakOutsideWorkingInterval
        }
    }
}
