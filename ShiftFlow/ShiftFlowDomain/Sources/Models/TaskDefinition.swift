// ShiftFlow — Domain Layer
// Models/TaskDefinition.swift
//
// TASK-TASK-001: Task definition model.
//
// A TaskDefinition is additional work attached to a WorkDay (e.g., MW, Ticket).
// It is a SEPARATE concept from ShiftDefinition/ScheduleRule and NEVER affects
// shift times, break times, reminders, or WorkDay snapshots.

import Foundation

/// Represents a configurable task type (e.g., "MW", "Ticket", "Zalo").
///
/// Tasks are attached to WorkDays via `WorkDayTask`. They carry no schedule
/// information and never influence shift resolution.
public struct TaskDefinition: Identifiable, Equatable, Codable, Sendable {

    public let id: UUID
    /// Stable code (e.g., "MW"). Immutable after creation.
    public let code: String
    /// Display name.
    public let name: String
    public let isActive: Bool
    public let createdAt: Date
    public let modifiedAt: Date

    public init(
        id: UUID = UUID(),
        code: String,
        name: String,
        isActive: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.isActive = isActive
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Returns a copy with edited fields. `id` and `code` are preserved (stable identity).
    public func withEdits(
        name: String? = nil,
        isActive: Bool? = nil,
        modifiedAt: Date = Date()
    ) -> TaskDefinition {
        TaskDefinition(
            id: id,
            code: code, // stable — never changes
            name: name ?? self.name,
            isActive: isActive ?? self.isActive,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

/// Represents the assignment of a TaskDefinition to a WorkDay.
///
/// This is the join between WorkDay and TaskDefinition. It carries NO schedule
/// data — assigning/removing it never changes the WorkDay's resolved times.
public struct WorkDayTask: Identifiable, Equatable, Codable, Sendable {

    public let id: UUID
    public let workDayID: UUID
    public let taskDefinitionID: UUID
    public let createdAt: Date
    public let modifiedAt: Date

    public init(
        id: UUID = UUID(),
        workDayID: UUID,
        taskDefinitionID: UUID,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.workDayID = workDayID
        self.taskDefinitionID = taskDefinitionID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
