// ShiftFlow — Persistence Layer
// SwiftData/WorkDayTaskModel.swift
//
// TASK-PERSISTENCE-001: SwiftData model for WorkDayTask (assignment join).
//
// Persistence-layer @Model only. Holds ONLY the relationship between a
// WorkDay and a TaskDefinition. MUST NOT contain shift times, reminder info,
// resolved dates, note, or any scheduling logic.
//
// CloudKit compatibility: no @Attribute(.unique); defaults; stable UUID.

import Foundation
import SwiftData
import ShiftFlowDomain

/// SwiftData persistence model for a WorkDay↔Task assignment.
@Model
public final class WorkDayTaskModel {

    public var id: UUID = UUID()
    public var workDayID: UUID = UUID()
    public var taskDefinitionID: UUID = UUID()
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()

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

public extension WorkDayTaskModel {

    convenience init(from domain: WorkDayTask) {
        self.init(
            id: domain.id,
            workDayID: domain.workDayID,
            taskDefinitionID: domain.taskDefinitionID,
            createdAt: domain.createdAt,
            modifiedAt: domain.modifiedAt
        )
    }

    func toDomain() -> WorkDayTask {
        WorkDayTask(
            id: id,
            workDayID: workDayID,
            taskDefinitionID: taskDefinitionID,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    func update(from domain: WorkDayTask) {
        self.workDayID = domain.workDayID
        self.taskDefinitionID = domain.taskDefinitionID
        self.modifiedAt = domain.modifiedAt
    }
}
