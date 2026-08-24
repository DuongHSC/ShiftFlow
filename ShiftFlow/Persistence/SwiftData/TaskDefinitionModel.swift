// ShiftFlow — Persistence Layer
// SwiftData/TaskDefinitionModel.swift
//
// TASK-PERSISTENCE-001: SwiftData model for TaskDefinition.
//
// Persistence-layer @Model only. No business logic. Maps to/from the pure
// domain `TaskDefinition` value type.
//
// CloudKit compatibility: no @Attribute(.unique); defaults on stored props;
// stable UUID (MW keeps its stable id).

import Foundation
import SwiftData
import ShiftFlowDomain

/// SwiftData persistence model for a task definition.
@Model
public final class TaskDefinitionModel {

    public var id: UUID = UUID()
    /// Stable business identity (e.g., "MW"). Not changed by editing.
    public var code: String = ""
    public var name: String = ""
    public var isActive: Bool = true
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()

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
}

public extension TaskDefinitionModel {

    convenience init(from domain: TaskDefinition) {
        self.init(
            id: domain.id,
            code: domain.code,
            name: domain.name,
            isActive: domain.isActive,
            createdAt: domain.createdAt,
            modifiedAt: domain.modifiedAt
        )
    }

    func toDomain() -> TaskDefinition {
        TaskDefinition(
            id: id,
            code: code,
            name: name,
            isActive: isActive,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    /// Updates fields from a domain value. id/code preserved (stable identity).
    func update(from domain: TaskDefinition) {
        self.name = domain.name
        self.isActive = domain.isActive
        self.modifiedAt = domain.modifiedAt
    }
}
