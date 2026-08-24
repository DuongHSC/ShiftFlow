// ShiftFlow — Domain Layer
// Import/ShiftImportService.swift
//
// TASK-IMPORT-001: Orchestrates the full Excel import workflow.
//
// Flow:
// 1. Parse file → ImportRawRow[]
// 2. Validate → ImportValidatedRow[]
// 3. Build preview → ImportPreview
// 4. User confirms (with conflict strategy)
// 5. Execute import → WorkDayService → ShiftResolver → WorkDay
//
// CRITICAL:
// - The importer NEVER calculates shift times itself.
// - All resolution goes through WorkDayService → ShiftResolver.
// - Tasks/Notes do NOT influence shift resolution.
// - OFF rows do NOT create WorkDays.

import Foundation

/// Service that orchestrates the full shift import workflow.
///
/// Usage:
/// ```swift
/// let service = ShiftImportService(workDayService: wds, shiftLookup: provider)
/// let preview = try service.prepareImport(content: csvContent)
/// let result = try service.executeImport(preview: preview, strategy: .skipExisting)
/// ```
public final class ShiftImportService {

    private let workDayService: WorkDayService
    private let shiftLookup: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])?
    private let calendar: Calendar

    /// Optional task service. When provided, the Task column is validated
    /// (unknown codes rejected) and tasks are assigned to created WorkDays.
    /// Task assignment NEVER modifies the WorkDay snapshot.
    private let taskService: TaskService?

    /// Initializes the import service.
    ///
    /// - Parameters:
    ///   - workDayService: The WorkDayService for CRUD operations.
    ///   - shiftLookup: Closure that resolves a shift code to its definition and rules.
    ///     Returns nil if the shift code is unknown.
    ///   - taskService: Optional TaskService for task validation/assignment.
    ///   - calendar: Calendar for date operations.
    public init(
        workDayService: WorkDayService,
        shiftLookup: @escaping (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])?,
        taskService: TaskService? = nil,
        calendar: Calendar = .current
    ) {
        self.workDayService = workDayService
        self.shiftLookup = shiftLookup
        self.taskService = taskService
        self.calendar = calendar
    }

    /// Known task codes for import validation (empty = task validation skipped).
    private var knownTaskCodes: Set<String> {
        guard let taskService = taskService else { return [] }
        return Set(taskService.allTasks().map { $0.code })
    }

    // MARK: - Prepare Import (Parse + Validate + Preview)

    /// Parses and validates file content, producing an import preview.
    ///
    /// This does NOT modify any data. It only produces a preview for user review.
    ///
    /// - Parameter content: The raw text content of the import file.
    /// - Returns: An `ImportPreview` with validated rows and status.
    /// - Throws: `ImportParseError` if the file cannot be parsed.
    public func prepareImport(content: String) throws -> ImportPreview {
        // Step 1: Parse.
        let rawRows = try ShiftFileParser.parse(content: content)

        // Step 2: Collect existing WorkDay dates for conflict detection.
        let existingDates = collectExistingDates(for: rawRows)

        // Step 3: Validate (includes task-code validation when a task service exists).
        let validatedRows = ImportValidator.validate(
            rows: rawRows,
            existingWorkDayDates: existingDates,
            calendar: calendar,
            knownTaskCodes: knownTaskCodes
        )

        // Step 4: Build preview.
        return ImportPreview(rows: validatedRows)
    }

    /// Parses and validates a file at the given URL.
    ///
    /// - Parameter url: URL to the import file.
    /// - Returns: An `ImportPreview`.
    /// - Throws: `ImportParseError` if the file cannot be read or parsed.
    public func prepareImport(url: URL) throws -> ImportPreview {
        let rawRows = try ShiftFileParser.parse(url: url)

        let existingDates = collectExistingDates(for: rawRows)

        let validatedRows = ImportValidator.validate(
            rows: rawRows,
            existingWorkDayDates: existingDates,
            calendar: calendar,
            knownTaskCodes: knownTaskCodes
        )

        return ImportPreview(rows: validatedRows)
    }

    // MARK: - Execute Import (Confirmed)

    /// Executes the import after user confirmation.
    ///
    /// Only valid rows are imported. OFF rows are skipped (counted as offDays).
    /// Error and duplicate rows are skipped entirely.
    /// Conflict rows are handled according to the specified strategy.
    ///
    /// - Parameters:
    ///   - preview: The previously generated import preview.
    ///   - strategy: How to handle existing WorkDay conflicts.
    /// - Returns: An `ImportResult` summarizing the operation.
    ///
    /// TASK-WIDGET-002 note: Each WorkDay mutation goes through WorkDayService,
    /// which refreshes the widget snapshot after each successful persistence.
    /// Because the refresh rebuilds the snapshot from the repository each time,
    /// the final widget state is always correct. Only successfully persisted
    /// WorkDays affect the widget. If the import throws mid-way, already-persisted
    /// rows remain and the widget reflects them (partial import is honored).
    public func executeImport(
        preview: ImportPreview,
        strategy: ImportConflictStrategy
    ) throws -> ImportResult {
        var created = 0
        var replaced = 0
        var skipped = 0
        var offDays = 0

        for row in preview.rows {
            // Skip error and duplicate rows.
            switch row.status {
            case .error, .duplicateInFile:
                continue
            case .valid, .conflict:
                break
            }

            // Handle OFF rows: no WorkDay created.
            if row.isOff {
                offDays += 1
                continue
            }

            guard let date = row.date,
                  let shiftCode = row.shiftCode else {
                continue
            }

            // Look up shift definition.
            guard let (shift, rules) = shiftLookup(shiftCode) else {
                continue
            }

            let note = row.note

            // Handle based on status.
            switch row.status {
            case .valid:
                // Create new WorkDay via WorkDayService (uses ShiftResolver internally).
                let workDay = try workDayService.createWorkDay(
                    date: date,
                    shift: shift,
                    rules: rules,
                    note: note
                )
                // Assign tasks (separate from note; never affects snapshot).
                assignTasks(row.task, toWorkDay: workDay.id)
                created += 1

            case .conflict:
                switch strategy {
                case .skipExisting:
                    skipped += 1

                case .replaceExisting:
                    if let existing = try workDayService.fetchWorkDay(date: date) {
                        // Change shift (re-resolves via ShiftResolver).
                        let _ = try workDayService.changeShift(
                            workDayID: existing.id,
                            newShift: shift,
                            rules: rules
                        )
                        // Update note.
                        let _ = try workDayService.updateNote(
                            workDayID: existing.id,
                            note: note
                        )
                        // Replace task assignments from the import row.
                        taskService?.removeAllTasks(forWorkDay: existing.id)
                        assignTasks(row.task, toWorkDay: existing.id)
                        replaced += 1
                    } else {
                        // Conflict detected but WorkDay no longer exists — create.
                        let workDay = try workDayService.createWorkDay(
                            date: date, shift: shift, rules: rules, note: note
                        )
                        assignTasks(row.task, toWorkDay: workDay.id)
                        created += 1
                    }
                }

            case .error, .duplicateInFile:
                continue
            }
        }

        return ImportResult(
            created: created,
            replaced: replaced,
            skipped: skipped,
            offDays: offDays
        )
    }

    // MARK: - Private Helpers

    /// Assigns tasks (from a `;`-separated task string) to a WorkDay.
    /// No-op if no task service is configured. Never modifies the WorkDay snapshot.
    private func assignTasks(_ taskString: String?, toWorkDay workDayID: UUID) {
        guard let taskService = taskService,
              let taskString = taskString, !taskString.isEmpty else { return }

        let codes = taskString
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for code in codes {
            if let def = taskService.task(withCode: code) {
                try? taskService.addTask(taskDefinitionID: def.id, toWorkDay: workDayID)
            }
        }
    }

    /// Collects normalized dates of existing WorkDays that overlap with import rows.
    private func collectExistingDates(for rawRows: [ImportRawRow]) -> Set<Date> {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.calendar = calendar
        formatter.isLenient = false

        var existingDates = Set<Date>()

        for row in rawRows {
            guard let dateString = row.dateString,
                  let date = formatter.date(from: dateString) else {
                continue
            }
            let normalized = calendar.startOfDay(for: date)
            if let _ = try? workDayService.fetchWorkDay(date: normalized) {
                existingDates.insert(normalized)
            }
        }

        return existingDates
    }
}
