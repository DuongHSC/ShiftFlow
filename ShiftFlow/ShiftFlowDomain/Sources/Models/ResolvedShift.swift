// ShiftFlow — Domain Layer
// Models/ResolvedShift.swift
//
// TASK-SHIFT-001: ResolvedShift value type implementation.
//
// ResolvedShift is a domain value/result, NOT a user configuration.
// It represents the exact, concrete schedule applicable to one specific date
// after applying all relevant ScheduleRules to a ShiftDefinition.
//
// This provides all values required by the later WorkDay snapshot (TASK-WORKDAY-001).

import Foundation

/// The fully resolved schedule for a specific date and shift.
///
/// This is the output of `ShiftResolver.resolve(...)`.
/// It contains concrete `Date` values (date + time) that represent
/// the exact working schedule for one calendar day.
public struct ResolvedShift: Equatable, Sendable {

    /// Reference to the ShiftDefinition that was resolved.
    public let shiftID: UUID

    /// The shift code (e.g., "C1", "C5").
    public let shiftCode: String

    /// The calendar date this resolution applies to.
    public let date: Date

    /// The resolved shift start date-time.
    public let startDateTime: Date

    /// The resolved shift end date-time.
    public let endDateTime: Date

    /// The resolved break start date-time.
    public let breakStartDateTime: Date

    /// The resolved break end date-time.
    public let breakEndDateTime: Date

    public init(
        shiftID: UUID,
        shiftCode: String,
        date: Date,
        startDateTime: Date,
        endDateTime: Date,
        breakStartDateTime: Date,
        breakEndDateTime: Date
    ) {
        self.shiftID = shiftID
        self.shiftCode = shiftCode
        self.date = date
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.breakStartDateTime = breakStartDateTime
        self.breakEndDateTime = breakEndDateTime
    }
}
