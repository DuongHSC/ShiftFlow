// ShiftFlow — Persistence Layer
// SwiftData/SwiftDataTaskStore.swift
//
// TASK-PERSISTENCE-001: SwiftData-backed TaskStore.
//
// Conforms to the domain `TaskStore` protocol using SwiftData. Persists
// TaskDefinitionModel + WorkDayTaskModel. No business logic here — TaskService
// enforces rules (delete protection, validation, seeding).

import Foundation
import SwiftData
import ShiftFlowDomain

/// SwiftData implementation of `TaskStore`.
public final class SwiftDataTaskStore: TaskStore {

    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Task Definitions

    public func allTaskDefinitions() -> [TaskDefinition] {
        let descriptor = FetchDescriptor<TaskDefinitionModel>(
            sortBy: [SortDescriptor(\.code, order: .forward)]
        )
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return models.map { $0.toDomain() }
    }

    public func upsertTaskDefinition(_ task: TaskDefinition) {
        if let existing = fetchTaskModel(id: task.id) {
            existing.update(from: task)
        } else {
            modelContext.insert(TaskDefinitionModel(from: task))
        }
        try? modelContext.save()
    }

    public func deleteTaskDefinition(id: UUID) {
        if let existing = fetchTaskModel(id: id) {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    // MARK: - Assignments

    public func assignments() -> [WorkDayTask] {
        let descriptor = FetchDescriptor<WorkDayTaskModel>()
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return models.map { $0.toDomain() }
    }

    public func assignments(forWorkDay workDayID: UUID) -> [WorkDayTask] {
        let descriptor = FetchDescriptor<WorkDayTaskModel>(
            predicate: #Predicate { $0.workDayID == workDayID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return models.map { $0.toDomain() }
    }

    public func upsertAssignment(_ assignment: WorkDayTask) {
        if let existing = fetchAssignmentModel(id: assignment.id) {
            existing.update(from: assignment)
        } else {
            modelContext.insert(WorkDayTaskModel(from: assignment))
        }
        try? modelContext.save()
    }

    public func deleteAssignment(id: UUID) {
        if let existing = fetchAssignmentModel(id: id) {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    public func deleteAssignments(forWorkDay workDayID: UUID) {
        let descriptor = FetchDescriptor<WorkDayTaskModel>(
            predicate: #Predicate { $0.workDayID == workDayID }
        )
        let models = (try? modelContext.fetch(descriptor)) ?? []
        for model in models { modelContext.delete(model) }
        if !models.isEmpty { try? modelContext.save() }
    }

    // MARK: - Private Helpers

    private func fetchTaskModel(id: UUID) -> TaskDefinitionModel? {
        let descriptor = FetchDescriptor<TaskDefinitionModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchAssignmentModel(id: UUID) -> WorkDayTaskModel? {
        let descriptor = FetchDescriptor<WorkDayTaskModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
