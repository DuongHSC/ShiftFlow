// ShiftFlow — Domain Layer
// Services/TaskService.swift
//
// TASK-TASK-001: Task definition + WorkDayTask management.
//
// CRITICAL INVARIANTS:
// - Task operations NEVER call ShiftResolver.
// - Task operations NEVER modify WorkDay resolved snapshots.
// - Task is NEVER stored in WorkDay.note.
// - This service contains no schedule-resolution logic.

import Foundation

/// Errors produced by task management.
public enum TaskError: Error, Equatable {
    case emptyCode
    case emptyName
    case duplicateCode(String)
    case notFound
    /// Deletion blocked because the task is still referenced by WorkDays.
    case taskInUse(String)
}

// MARK: - Task Store

/// Persists task definitions and WorkDay↔task assignments.
public protocol TaskStore: AnyObject {
    func allTaskDefinitions() -> [TaskDefinition]
    func upsertTaskDefinition(_ task: TaskDefinition)
    func deleteTaskDefinition(id: UUID)

    func assignments() -> [WorkDayTask]
    func assignments(forWorkDay workDayID: UUID) -> [WorkDayTask]
    func upsertAssignment(_ assignment: WorkDayTask)
    func deleteAssignment(id: UUID)
    func deleteAssignments(forWorkDay workDayID: UUID)
}

/// In-memory task store (default for app + tests).
public final class InMemoryTaskStore: TaskStore {
    private var definitions: [UUID: TaskDefinition] = [:]
    private var joins: [UUID: WorkDayTask] = [:]

    public init(seed: Bool = true) {
        if seed {
            for t in TaskSeedProvider.allDefaultTasks() { definitions[t.id] = t }
        }
    }

    public func allTaskDefinitions() -> [TaskDefinition] {
        definitions.values.sorted { $0.code < $1.code }
    }
    public func upsertTaskDefinition(_ task: TaskDefinition) { definitions[task.id] = task }
    public func deleteTaskDefinition(id: UUID) { definitions.removeValue(forKey: id) }

    public func assignments() -> [WorkDayTask] { Array(joins.values) }
    public func assignments(forWorkDay workDayID: UUID) -> [WorkDayTask] {
        joins.values.filter { $0.workDayID == workDayID }.sorted { $0.createdAt < $1.createdAt }
    }
    public func upsertAssignment(_ assignment: WorkDayTask) { joins[assignment.id] = assignment }
    public func deleteAssignment(id: UUID) { joins.removeValue(forKey: id) }
    public func deleteAssignments(forWorkDay workDayID: UUID) {
        for j in joins.values where j.workDayID == workDayID { joins.removeValue(forKey: j.id) }
    }
}

// MARK: - Task Service

/// Manages task definitions and WorkDay task assignments.
///
/// Deletion policy: a TaskDefinition referenced by existing WorkDayTask records
/// CANNOT be deleted (throws `.taskInUse`). The user should disable it instead.
/// This preserves historical task assignments.
public final class TaskService {

    private let store: TaskStore

    public init(store: TaskStore) {
        self.store = store
    }

    // MARK: - Seeding

    /// Seeds default tasks (MW) idempotently — only missing IDs are added.
    public func seedIfNeeded() {
        let existing = Set(store.allTaskDefinitions().map { $0.id })
        for t in TaskSeedProvider.tasksToSeed(existingIDs: existing) {
            store.upsertTaskDefinition(t)
        }
    }

    /// Restores default task definitions (MW) without duplicating existing ones,
    /// removing custom tasks, or touching any WorkDayTask assignment.
    ///
    /// This is deliberately conservative: it re-adds any missing default (by
    /// stable ID) and leaves everything else — including custom tasks and all
    /// historical assignments — untouched. It NEVER modifies WorkDay snapshots.
    public func resetDefaults() {
        seedIfNeeded()
    }

    // MARK: - TaskDefinition CRUD

    public func allTasks() -> [TaskDefinition] { store.allTaskDefinitions() }

    public func activeTasks() -> [TaskDefinition] {
        store.allTaskDefinitions().filter { $0.isActive }
    }

    public func task(withCode code: String) -> TaskDefinition? {
        store.allTaskDefinitions().first { $0.code.uppercased() == code.uppercased() }
    }

    public func task(withID id: UUID) -> TaskDefinition? {
        store.allTaskDefinitions().first { $0.id == id }
    }

    /// Creates a new task definition after validation.
    @discardableResult
    public func createTask(code: String, name: String) throws -> TaskDefinition {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedCode.isEmpty { throw TaskError.emptyCode }
        if trimmedName.isEmpty { throw TaskError.emptyName }
        if store.allTaskDefinitions().contains(where: { $0.code.uppercased() == trimmedCode.uppercased() }) {
            throw TaskError.duplicateCode(trimmedCode)
        }
        let task = TaskDefinition(code: trimmedCode, name: trimmedName)
        store.upsertTaskDefinition(task)
        return task
    }

    /// Updates an existing task's name/active state. Code is stable.
    public func updateTask(_ updated: TaskDefinition) throws {
        guard store.allTaskDefinitions().contains(where: { $0.id == updated.id }) else {
            throw TaskError.notFound
        }
        if updated.name.trimmingCharacters(in: .whitespaces).isEmpty { throw TaskError.emptyName }
        store.upsertTaskDefinition(updated)
    }

    /// Enables/disables a task. Historical assignments are preserved.
    public func setTaskActive(id: UUID, isActive: Bool) throws {
        guard let existing = task(withID: id) else { throw TaskError.notFound }
        store.upsertTaskDefinition(existing.withEdits(isActive: isActive))
    }

    /// Deletes a task definition.
    ///
    /// Deletion policy: refuses if the task is referenced by any WorkDayTask
    /// (throws `.taskInUse`). Preserves historical assignments — user disables instead.
    public func deleteTask(id: UUID) throws {
        guard let existing = task(withID: id) else { throw TaskError.notFound }
        let referenced = store.assignments().contains { $0.taskDefinitionID == id }
        if referenced { throw TaskError.taskInUse(existing.code) }
        store.deleteTaskDefinition(id: id)
    }

    // MARK: - WorkDay Task Assignment

    /// Tasks currently assigned to a WorkDay (as TaskDefinitions).
    public func tasks(forWorkDay workDayID: UUID) -> [TaskDefinition] {
        let joins = store.assignments(forWorkDay: workDayID)
        return joins.compactMap { task(withID: $0.taskDefinitionID) }
    }

    /// Whether a WorkDay has at least one task assigned.
    public func hasTask(workDayID: UUID) -> Bool {
        !store.assignments(forWorkDay: workDayID).isEmpty
    }

    /// Adds a task to a WorkDay (idempotent — no duplicate join for same pair).
    /// Does NOT modify the WorkDay snapshot.
    public func addTask(taskDefinitionID: UUID, toWorkDay workDayID: UUID) throws {
        guard task(withID: taskDefinitionID) != nil else { throw TaskError.notFound }
        // Avoid duplicate assignment of the same task to the same WorkDay.
        let existing = store.assignments(forWorkDay: workDayID)
        if existing.contains(where: { $0.taskDefinitionID == taskDefinitionID }) { return }
        store.upsertAssignment(WorkDayTask(workDayID: workDayID, taskDefinitionID: taskDefinitionID))
    }

    /// Removes a task from a WorkDay. Does NOT modify the WorkDay snapshot.
    public func removeTask(taskDefinitionID: UUID, fromWorkDay workDayID: UUID) {
        let joins = store.assignments(forWorkDay: workDayID)
            .filter { $0.taskDefinitionID == taskDefinitionID }
        for j in joins { store.deleteAssignment(id: j.id) }
    }

    /// Removes all task assignments for a WorkDay (called when a WorkDay is deleted).
    public func removeAllTasks(forWorkDay workDayID: UUID) {
        store.deleteAssignments(forWorkDay: workDayID)
    }

    /// Set of WorkDay IDs that have at least one task (for widget/calendar indicators).
    public func workDayIDsWithTasks() -> Set<UUID> {
        Set(store.assignments().map { $0.workDayID })
    }
}
