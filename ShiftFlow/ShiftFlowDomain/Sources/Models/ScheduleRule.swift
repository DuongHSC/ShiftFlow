// ShiftFlow — Domain Layer
// Models/ScheduleRule.swift
//
// TASK-SHIFT-001: ScheduleRule model implementation.
//
// ScheduleRule represents a conditional schedule override for a shift.
// Example: C5 uses different times on calendar days 10–20 inclusive.

import Foundation

/// Represents a conditional schedule override applied to a ShiftDefinition.
///
/// When the day-of-month falls within [startDayOfMonth, endDayOfMonth] inclusive,
/// the schedule rule's times override the shift definition's default times.
public struct ScheduleRule: Identifiable, Equatable, Sendable {

    public let id: UUID
    public let shiftID: UUID

    /// First day of the month (inclusive) when this rule applies.
    /// Range: 1–31.
    public let startDayOfMonth: Int

    /// Last day of the month (inclusive) when this rule applies.
    /// Range: 1–31.
    public let endDayOfMonth: Int

    /// Override start time components (hour, minute).
    public let startHour: Int
    public let startMinute: Int

    /// Override end time components (hour, minute).
    public let endHour: Int
    public let endMinute: Int

    /// Override break start time components (hour, minute).
    public let breakStartHour: Int
    public let breakStartMinute: Int

    /// Override break end time components (hour, minute).
    public let breakEndHour: Int
    public let breakEndMinute: Int

    /// Higher priority rules override lower priority rules when ranges overlap.
    public let priority: Int

    public let isActive: Bool

    public init(
        id: UUID = UUID(),
        shiftID: UUID,
        startDayOfMonth: Int,
        endDayOfMonth: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        breakStartHour: Int,
        breakStartMinute: Int,
        breakEndHour: Int,
        breakEndMinute: Int,
        priority: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.shiftID = shiftID
        self.startDayOfMonth = startDayOfMonth
        self.endDayOfMonth = endDayOfMonth
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.breakStartHour = breakStartHour
        self.breakStartMinute = breakStartMinute
        self.breakEndHour = breakEndHour
        self.breakEndMinute = breakEndMinute
        self.priority = priority
        self.isActive = isActive
    }

    /// Determines whether this rule applies to a given day of the month.
    ///
    /// The check is inclusive on both boundaries:
    /// `startDayOfMonth <= dayOfMonth <= endDayOfMonth`
    public func applies(toDayOfMonth dayOfMonth: Int) -> Bool {
        guard isActive else { return false }
        return dayOfMonth >= startDayOfMonth && dayOfMonth <= endDayOfMonth
    }
}
