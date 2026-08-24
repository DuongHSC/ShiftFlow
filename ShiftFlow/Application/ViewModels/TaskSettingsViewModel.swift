// ShiftFlow — Application Layer
// ViewModels/TaskSettingsViewModel.swift
//
// TASK-TASK-002: ViewModel for Task Settings management.
//
// Coordinates TaskService for the UI. Contains NO shift-resolution logic and
// NEVER modifies WorkDay snapshots. TaskService remains the single source of truth.

import Foundation
import SwiftUI
import ShiftFlowDomain

/// ViewModel backing the Task Settings ("Loại công việc") UI.
@Observable
public final class TaskSettingsViewModel {

    // MARK: - Published State

    /// All tasks, sorted: active first, then inactive; each group by code ascending.
    public var tasks: [TaskDefinition] = []
    public var errorMessage: String?

    // MARK: - Dependencies

    private let taskService: TaskService

    public init(taskService: TaskService) {
        self.taskService = taskService
        reload()
    }

    // MARK: - Load

    public func reload() {
        let all = taskService.allTasks()
        tasks = all.sorted { a, b in
            if a.isActive != b.isActive {
                return a.isActive && !b.isActive // active first
            }
            return a.code.uppercased() < b.code.uppercased()
        }
    }

    // MARK: - Create

    /// Creates a task. Returns true on success.
    @discardableResult
    public func createTask(code: String, name: String) -> Bool {
        errorMessage = nil
        do {
            _ = try taskService.createTask(code: code, name: name)
            reload()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    // MARK: - Edit

    /// Updates a task's name/active state. Code is preserved (stable identity).
    @discardableResult
    public func updateTask(_ task: TaskDefinition, name: String, isActive: Bool) -> Bool {
        errorMessage = nil
        do {
            try taskService.updateTask(task.withEdits(name: name, isActive: isActive))
            reload()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    // MARK: - Enable / Disable

    @discardableResult
    public func setActive(_ task: TaskDefinition, isActive: Bool) -> Bool {
        errorMessage = nil
        do {
            try taskService.setTaskActive(id: task.id, isActive: isActive)
            reload()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    // MARK: - Delete

    /// Whether a task can be deleted (not referenced by any WorkDay).
    public func canDelete(_ task: TaskDefinition) -> Bool {
        !taskService.workDayIDsWithTasks().isEmpty
            ? !isTaskReferenced(task)
            : true
    }

    private func isTaskReferenced(_ task: TaskDefinition) -> Bool {
        taskService.allTasks().contains { $0.id == task.id }
            && referencedTaskIDs().contains(task.id)
    }

    private func referencedTaskIDs() -> Set<UUID> {
        // Derived from assignments; TaskService enforces the actual rule on delete.
        Set(taskService.workDayIDsWithTasks().flatMap { workDayID in
            taskService.tasks(forWorkDay: workDayID).map { $0.id }
        })
    }

    /// Deletes a task. Returns true on success. Fails (with message) if in use.
    @discardableResult
    public func deleteTask(_ task: TaskDefinition) -> Bool {
        errorMessage = nil
        do {
            try taskService.deleteTask(id: task.id)
            reload()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    // MARK: - Accessibility

    /// Accessibility label for a task row.
    public func accessibilityLabel(for task: TaskDefinition) -> String {
        let state = task.isActive ? "đang bật" : "đã tắt"
        return "Công việc \(task.code), \(task.name), \(state)"
    }
}
