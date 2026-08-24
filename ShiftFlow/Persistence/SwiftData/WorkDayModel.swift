// ShiftFlow — Persistence Layer
// SwiftData/WorkDayModel.swift
//
// TASK-WORKDAY-001: SwiftData persistence model for WorkDay.
// TASK-CLOUDKIT-001: Made CloudKit-compatible.
//
// This is the @Model representation stored in SwiftData.
// It maps to/from the domain WorkDay value type.
//
// IMPORTANT:
// - The resolved snapshot fields are stored directly.
// - Changing global ShiftDefinition does NOT modify these stored values.
// - Only explicit WorkDay edit operations update the snapshot.
//
// CLOUDKIT COMPATIBILITY:
// - CloudKit does NOT support @Attribute(.unique). The uniqueness constraint
//   was removed. "One WorkDay per date" is enforced at the WorkDayService /
//   SyncConflictResolver layer instead.
// - All non-optional stored properties have default values (required by
//   SwiftData + CloudKit). Optional properties are allowed.

import Foundation
import SwiftData
import ShiftFlowDomain

/// SwiftData persistence model for a scheduled work day.
///
/// Stores the historical snapshot of resolved working times.
/// One WorkDayModel per calendar date (enforced at the service layer,
/// since CloudKit does not support unique constraints).
@Model
public final class WorkDayModel {

    /// Identifier (NOT a SwiftData unique constraint — CloudKit incompatible).
    /// Uniqueness by date is enforced at the service layer.
    public var id: UUID = UUID()

    /// The calendar date (year/month/day). Time components should be midnight.
    public var date: Date = Date()

    /// Reference to the ShiftDefinition ID.
    public var shiftID: UUID = UUID()

    /// The shift code at the time of resolution (e.g., "C1", "C5").
    public var shiftCode: String = ""

    // MARK: - Historical Snapshot

    /// Resolved shift start date-time.
    public var resolvedStartDateTime: Date = Date()

    /// Resolved shift end date-time.
    public var resolvedEndDateTime: Date = Date()

    /// Resolved break start date-time.
    public var resolvedBreakStartDateTime: Date = Date()

    /// Resolved break end date-time.
    public var resolvedBreakEndDateTime: Date = Date()

    // MARK: - Optional

    /// Optional plain-text note.
    public var note: String?

    // MARK: - Timestamps

    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        date: Date,
        shiftID: UUID,
        shiftCode: String,
        resolvedStartDateTime: Date,
        resolvedEndDateTime: Date,
        resolvedBreakStartDateTime: Date,
        resolvedBreakEndDateTime: Date,
        note: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
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
}

// MARK: - Domain Mapping

public extension WorkDayModel {

    /// Creates a WorkDayModel from a domain WorkDay value.
    convenience init(from workDay: WorkDay) {
        self.init(
            id: workDay.id,
            date: workDay.date,
            shiftID: workDay.shiftID,
            shiftCode: workDay.shiftCode,
            resolvedStartDateTime: workDay.resolvedStartDateTime,
            resolvedEndDateTime: workDay.resolvedEndDateTime,
            resolvedBreakStartDateTime: workDay.resolvedBreakStartDateTime,
            resolvedBreakEndDateTime: workDay.resolvedBreakEndDateTime,
            note: workDay.note,
            createdAt: workDay.createdAt,
            modifiedAt: workDay.modifiedAt
        )
    }

    /// Converts to a domain WorkDay value.
    func toDomain() -> WorkDay {
        WorkDay(
            id: id,
            date: date,
            shiftID: shiftID,
            shiftCode: shiftCode,
            resolvedStartDateTime: resolvedStartDateTime,
            resolvedEndDateTime: resolvedEndDateTime,
            resolvedBreakStartDateTime: resolvedBreakStartDateTime,
            resolvedBreakEndDateTime: resolvedBreakEndDateTime,
            note: note,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    /// Updates this model's fields from a domain WorkDay value.
    func update(from workDay: WorkDay) {
        self.shiftID = workDay.shiftID
        self.shiftCode = workDay.shiftCode
        self.resolvedStartDateTime = workDay.resolvedStartDateTime
        self.resolvedEndDateTime = workDay.resolvedEndDateTime
        self.resolvedBreakStartDateTime = workDay.resolvedBreakStartDateTime
        self.resolvedBreakEndDateTime = workDay.resolvedBreakEndDateTime
        self.note = workDay.note
        self.modifiedAt = workDay.modifiedAt
    }
}
