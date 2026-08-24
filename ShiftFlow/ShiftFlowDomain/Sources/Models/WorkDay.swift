// ShiftFlow — Domain Layer
// Models/WorkDay.swift
//
// TASK-WORKDAY-001: WorkDay domain model.
//
// WorkDay is the primary scheduled work record.
// It stores a historical snapshot of resolved working times.
//
// CRITICAL ARCHITECTURAL RULE:
// The resolved snapshot is captured at creation time (or explicit shift change).
// Changing a global ShiftDefinition MUST NOT automatically modify existing WorkDays.
//
// Snapshot is recalculated ONLY when:
// 1. A new WorkDay is created.
// 2. The user explicitly changes that WorkDay's selected shift.
// 3. A future explicit "recalculate" operation (if approved).

import Foundation

/// The primary scheduled work record in ShiftFlow.
///
/// A WorkDay represents one calendar date with an assigned shift.
/// It stores the resolved schedule as a point-in-time snapshot,
/// protecting historical data from future configuration changes.
///
/// There must be at most one WorkDay per calendar date.
public struct WorkDay: Identifiable, Equatable, Sendable {

    public let id: UUID

    /// The calendar date this WorkDay represents.
    /// Only the date component (year/month/day) is meaningful.
    public let date: Date

    /// Reference to the assigned ShiftDefinition.
    public let shiftID: UUID

    /// The shift code at time of resolution (e.g., "C1", "C5").
    /// Stored for display without needing to look up the ShiftDefinition.
    public let shiftCode: String

    // MARK: - Historical Snapshot

    /// The resolved shift start date-time (snapshot).
    public let resolvedStartDateTime: Date

    /// The resolved shift end date-time (snapshot).
    public let resolvedEndDateTime: Date

    /// The resolved break start date-time (snapshot).
    public let resolvedBreakStartDateTime: Date

    /// The resolved break end date-time (snapshot).
    public let resolvedBreakEndDateTime: Date

    // MARK: - Optional Properties

    /// Optional plain-text note attached to this WorkDay.
    /// Notes do not influence schedule resolution.
    public var note: String?

    // MARK: - Timestamps

    public let createdAt: Date
    public var modifiedAt: Date

    // MARK: - Initialization

    /// Creates a WorkDay from a ResolvedShift (the standard creation path).
    ///
    /// This captures the resolved schedule as the historical snapshot.
    /// The snapshot will not change unless the user explicitly changes the shift.
    public init(
        id: UUID = UUID(),
        date: Date,
        resolvedShift: ResolvedShift,
        note: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.shiftID = resolvedShift.shiftID
        self.shiftCode = resolvedShift.shiftCode
        self.resolvedStartDateTime = resolvedShift.startDateTime
        self.resolvedEndDateTime = resolvedShift.endDateTime
        self.resolvedBreakStartDateTime = resolvedShift.breakStartDateTime
        self.resolvedBreakEndDateTime = resolvedShift.breakEndDateTime
        self.note = note
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Creates a WorkDay with explicit field values (for persistence reconstitution).
    public init(
        id: UUID,
        date: Date,
        shiftID: UUID,
        shiftCode: String,
        resolvedStartDateTime: Date,
        resolvedEndDateTime: Date,
        resolvedBreakStartDateTime: Date,
        resolvedBreakEndDateTime: Date,
        note: String?,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.date = date
        self.shiftID = shiftID
        self.shiftCode = shiftCode
        self.resolvedStartDateTime = resolvedStartDateTime
        self.resolvedEndDateTime = resolvedEndDateTime
        self.resolvedBreakStartDateTime = resolvedBreakStartDateTime
        self.resolvedBreakEndDateTime = resolvedBreakEndDateTime
        self.note = note
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    // MARK: - Snapshot Update

    /// Returns a new WorkDay with an updated schedule snapshot from a new ResolvedShift.
    ///
    /// Used when the user explicitly changes the shift assignment.
    /// This is the ONLY approved path for modifying a WorkDay's resolved times.
    public func withUpdatedShift(_ resolvedShift: ResolvedShift, modifiedAt: Date = Date()) -> WorkDay {
        WorkDay(
            id: self.id,
            date: self.date,
            shiftID: resolvedShift.shiftID,
            shiftCode: resolvedShift.shiftCode,
            resolvedStartDateTime: resolvedShift.startDateTime,
            resolvedEndDateTime: resolvedShift.endDateTime,
            resolvedBreakStartDateTime: resolvedShift.breakStartDateTime,
            resolvedBreakEndDateTime: resolvedShift.breakEndDateTime,
            note: self.note,
            createdAt: self.createdAt,
            modifiedAt: modifiedAt
        )
    }

    /// Returns a new WorkDay with an updated note.
    public func withUpdatedNote(_ note: String?, modifiedAt: Date = Date()) -> WorkDay {
        WorkDay(
            id: self.id,
            date: self.date,
            shiftID: self.shiftID,
            shiftCode: self.shiftCode,
            resolvedStartDateTime: self.resolvedStartDateTime,
            resolvedEndDateTime: self.resolvedEndDateTime,
            resolvedBreakStartDateTime: self.resolvedBreakStartDateTime,
            resolvedBreakEndDateTime: self.resolvedBreakEndDateTime,
            note: note,
            createdAt: self.createdAt,
            modifiedAt: modifiedAt
        )
    }
}
