// ShiftFlow — Application Layer
// ViewModels/DayDetailViewModel.swift
//
// TASK-CALENDAR-001: Day Detail ViewModel.
//
// Manages the state for viewing/editing/creating a WorkDay.
// Delegates all shift resolution to WorkDayService → ShiftResolver.
// Does NOT contain shift-calculation logic.
//
// TASK/MW ARCHITECTURE:
// The `task` field is a display-only placeholder for the future Task model
// (TASK-TASK-001). It is NOT stored in WorkDay.note.
// Task and Note are independent concepts:
// - Task = separate TaskDefinition/WorkDayTask relationship (future)
// - Note = WorkDay.note plain text field
// MW must NEVER modify shift times.

import Foundation
import SwiftUI
import ShiftFlowDomain

/// ViewModel for the Day Detail sheet (view/edit/create).
@Observable
public final class DayDetailViewModel {

    // MARK: - State

    public var date: Date
    public var selectedShiftCode: String?
    public var resolvedStart: Date?
    public var resolvedEnd: Date?
    public var resolvedBreakStart: Date?
    public var resolvedBreakEnd: Date?
    /// Task definitions currently assigned to this WorkDay (structured, separate from note).
    /// NEVER stored in WorkDay.note. Independent from shift resolution.
    public var assignedTasks: [TaskDefinition] = []
    /// All active task definitions available for assignment.
    public var availableTasks: [TaskDefinition] = []
    public var note: String = ""
    public var hasUnsavedChanges: Bool = false
    public var showDeleteConfirmation: Bool = false
    public var showDiscardConfirmation: Bool = false
    public var errorMessage: String?
    public var isSaving: Bool = false

    /// The existing WorkDay (nil if creating new).
    public private(set) var existingWorkDay: WorkDay?

    /// Whether this is editing an existing WorkDay vs creating new.
    public var isEditing: Bool { existingWorkDay != nil }

    /// Whether the current date has OFF (no WorkDay).
    public var isOff: Bool { selectedShiftCode == nil && existingWorkDay == nil }

    // MARK: - Dependencies

    private let workDayService: WorkDayService
    private let shiftLookup: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])?
    private let taskService: TaskService?
    private let calendar: Calendar

    // MARK: - Initialization

    public init(
        date: Date,
        existingWorkDay: WorkDay?,
        workDayService: WorkDayService,
        shiftLookup: @escaping (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])?,
        taskService: TaskService? = nil,
        calendar: Calendar = .current
    ) {
        self.date = date
        self.existingWorkDay = existingWorkDay
        self.workDayService = workDayService
        self.shiftLookup = shiftLookup
        self.taskService = taskService
        self.calendar = calendar

        // Populate from existing WorkDay if available.
        if let wd = existingWorkDay {
            self.selectedShiftCode = wd.shiftCode
            self.resolvedStart = wd.resolvedStartDateTime
            self.resolvedEnd = wd.resolvedEndDateTime
            self.resolvedBreakStart = wd.resolvedBreakStartDateTime
            self.resolvedBreakEnd = wd.resolvedBreakEndDateTime
            self.note = wd.note ?? ""
        }

        // Load task data (separate from note).
        self.availableTasks = taskService?.activeTasks() ?? []
        if let wd = existingWorkDay {
            self.assignedTasks = taskService?.tasks(forWorkDay: wd.id) ?? []
        }
    }

    // MARK: - Task Management

    /// Loads tasks for the current WorkDay (call after save when creating).
    public func loadTasks() {
        availableTasks = taskService?.activeTasks() ?? []
        if let wd = existingWorkDay {
            assignedTasks = taskService?.tasks(forWorkDay: wd.id) ?? []
        }
    }

    /// Adds a task to the current WorkDay. Requires an existing WorkDay.
    /// Does NOT modify the shift snapshot.
    public func addTask(_ task: TaskDefinition) {
        guard let wd = existingWorkDay, let taskService = taskService else { return }
        try? taskService.addTask(taskDefinitionID: task.id, toWorkDay: wd.id)
        loadTasks()
    }

    /// Removes a task from the current WorkDay. Does NOT modify the shift snapshot.
    public func removeTask(_ task: TaskDefinition) {
        guard let wd = existingWorkDay, let taskService = taskService else { return }
        taskService.removeTask(taskDefinitionID: task.id, fromWorkDay: wd.id)
        loadTasks()
    }

    /// Toggles a task assignment.
    public func toggleTask(_ task: TaskDefinition) {
        if assignedTasks.contains(where: { $0.id == task.id }) {
            removeTask(task)
        } else {
            addTask(task)
        }
    }

    /// Whether a task is currently assigned.
    public func isTaskAssigned(_ task: TaskDefinition) -> Bool {
        assignedTasks.contains { $0.id == task.id }
    }

    // MARK: - Shift Selection

    /// Called when the user selects a shift code.
    /// Resolves the schedule immediately for display.
    public func selectShift(_ code: String) {
        if code == "OFF" {
            selectedShiftCode = nil
            resolvedStart = nil
            resolvedEnd = nil
            resolvedBreakStart = nil
            resolvedBreakEnd = nil
            hasUnsavedChanges = true
            return
        }

        guard let (shift, rules) = shiftLookup(code) else { return }

        let resolved = ShiftResolver.resolve(
            date: date,
            shift: shift,
            rules: rules,
            calendar: calendar
        )

        selectedShiftCode = code
        resolvedStart = resolved.startDateTime
        resolvedEnd = resolved.endDateTime
        resolvedBreakStart = resolved.breakStartDateTime
        resolvedBreakEnd = resolved.breakEndDateTime
        hasUnsavedChanges = true
    }

    /// Marks note as changed.
    public func updateNote(_ newNote: String) {
        note = newNote
        hasUnsavedChanges = true
    }

    // MARK: - Save

    /// Saves the WorkDay (create or update).
    /// Returns true on success.
    public func save() -> Bool {
        isSaving = true
        errorMessage = nil

        defer { isSaving = false }

        // OFF = delete existing if present.
        if selectedShiftCode == nil {
            if let existing = existingWorkDay {
                do {
                    try workDayService.deleteWorkDay(id: existing.id)
                    existingWorkDay = nil
                    hasUnsavedChanges = false
                    return true
                } catch {
                    errorMessage = UserFacingError.message(for: error)
                    return false
                }
            }
            hasUnsavedChanges = false
            return true
        }

        guard let code = selectedShiftCode,
              let (shift, rules) = shiftLookup(code) else {
            errorMessage = "Ca làm việc không hợp lệ."
            return false
        }

        do {
            if let existing = existingWorkDay {
                // Update existing: change shift if different, update note.
                if existing.shiftCode != code {
                    let updated = try workDayService.changeShift(
                        workDayID: existing.id, newShift: shift, rules: rules
                    )
                    existingWorkDay = updated
                }
                // Update note.
                let noteValue = note.isEmpty ? nil : note
                if existingWorkDay?.note != noteValue {
                    let updated = try workDayService.updateNote(
                        workDayID: existingWorkDay!.id, note: noteValue
                    )
                    existingWorkDay = updated
                }
            } else {
                // Create new WorkDay.
                let noteValue = note.isEmpty ? nil : note
                let created = try workDayService.createWorkDay(
                    date: date, shift: shift, rules: rules, note: noteValue
                )
                existingWorkDay = created
            }

            hasUnsavedChanges = false
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    // MARK: - Delete

    /// Deletes the existing WorkDay after confirmation.
    /// Returns true on success.
    public func confirmDelete() -> Bool {
        guard let existing = existingWorkDay else { return false }

        do {
            try workDayService.deleteWorkDay(id: existing.id)
            // Clean up task assignments for the deleted WorkDay.
            taskService?.removeAllTasks(forWorkDay: existing.id)
            existingWorkDay = nil
            selectedShiftCode = nil
            resolvedStart = nil
            resolvedEnd = nil
            resolvedBreakStart = nil
            resolvedBreakEnd = nil
            note = ""
            assignedTasks = []
            hasUnsavedChanges = false
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }
}
