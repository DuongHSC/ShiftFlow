// ShiftFlow — Domain Layer
// Models/ShiftDefinition.swift
//
// TASK-SHIFT-001: ShiftDefinition model implementation.
//
// ShiftDefinition represents a configurable shift with default working hours.
// It is a pure domain model independent of SwiftUI, WidgetKit, CloudKit, etc.

import Foundation

/// Represents a configurable shift definition.
///
/// Each shift has a code (e.g., "C1"–"C5"), default start/end times,
/// and default break times. These values serve as the baseline schedule
/// when no special ScheduleRule overrides apply.
public struct ShiftDefinition: Identifiable, Equatable, Sendable {

    public let id: UUID
    public let code: String
    public let name: String

    /// Default start time components (hour, minute).
    public let startHour: Int
    public let startMinute: Int

    /// Default end time components (hour, minute).
    public let endHour: Int
    public let endMinute: Int

    /// Default break start time components (hour, minute).
    public let breakStartHour: Int
    public let breakStartMinute: Int

    /// Default break end time components (hour, minute).
    public let breakEndHour: Int
    public let breakEndMinute: Int

    public let isActive: Bool
    public let createdAt: Date
    public let modifiedAt: Date

    public init(
        id: UUID = UUID(),
        code: String,
        name: String,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        breakStartHour: Int,
        breakStartMinute: Int,
        breakEndHour: Int,
        breakEndMinute: Int,
        isActive: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.breakStartHour = breakStartHour
        self.breakStartMinute = breakStartMinute
        self.breakEndHour = breakEndHour
        self.breakEndMinute = breakEndMinute
        self.isActive = isActive
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
