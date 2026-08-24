// ShiftFlow — Application Layer
// ViewModels/DataManagementViewModel.swift
//
// TASK-DATA-001: CSV Data Management view model.
//
// Wraps the EXISTING import/export domain services so the Settings UI can
// import and export ShiftFlow data. This view model contains NO parsing,
// NO validation, and NO shift-resolution logic of its own — it delegates
// entirely to:
//   - ShiftImportService  (parse → validate → preview → execute)
//   - ShiftExportService  (WorkDay → CSV / template)
//   - WorkDayService      (fetch WorkDays for export)
//   - TaskService         (task lookup for export/validation)
//   - UserFacingError     (Vietnamese error messages)
//
// CSV is the official interchange format for this task (Excel-compatible).
//
// INVARIANTS PRESERVED:
// - Import always flows CSV → ShiftImportService → WorkDayService → ShiftResolver.
//   The importer never computes shift times.
// - Export never includes resolved start/end/break and never mutates WorkDays.
// - Task and Note remain separate (handled by the domain services).
// - Historical WorkDay snapshots are never rewritten by import/export.
// - OFF creates no WorkDay; "replace" of an OFF row deletes the existing WorkDay.

import Foundation
import ShiftFlowDomain

/// View model for the Settings → Dữ liệu (Data Management) screen.
///
/// Pure application-layer state machine over the existing import/export
/// services. Uses `@Observable` for consistency with the other ShiftFlow
/// view models (CalendarViewModel, TaskSettingsViewModel, ShiftSettingsViewModel).
@Observable
public final class DataManagementViewModel {

    // MARK: - Dependencies (all existing services)

    @ObservationIgnored private let importService: ShiftImportService
    @ObservationIgnored private let exportService: ShiftExportService
    @ObservationIgnored private let workDayService: WorkDayService
    @ObservationIgnored private let taskService: TaskService
    @ObservationIgnored private let calendar: Calendar

    // MARK: - Observable State

    /// The generated import preview (nil until a file is parsed/validated).
    public private(set) var preview: ImportPreview?

    /// Conflict strategy chosen by the user. Default is skip (no silent overwrite).
    public var conflictStrategy: ImportConflictStrategy = .skipExisting

    /// The result of the last executed import (nil until an import runs).
    public private(set) var lastResult: ImportResult?

    /// A user-facing Vietnamese error message (nil when there is no error).
    public var errorMessage: String?

    /// Whether an import/export operation is currently in progress.
    public private(set) var isBusy: Bool = false

    // MARK: - Init

    public init(
        importService: ShiftImportService,
        exportService: ShiftExportService,
        workDayService: WorkDayService,
        taskService: TaskService,
        calendar: Calendar = .current
    ) {
        self.importService = importService
        self.exportService = exportService
        self.workDayService = workDayService
        self.taskService = taskService
        self.calendar = calendar
    }

    // MARK: - Export

    /// The official export file name for a given date: `ShiftFlow_YYYY-MM-DD.csv`.
    public func exportFileName(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = calendar
        return "ShiftFlow_\(f.string(from: date)).csv"
    }

    /// The official template file name.
    public var templateFileName: String { "ShiftFlow_Template.csv" }

    /// Builds the CSV export content for all stored WorkDays.
    ///
    /// Read-only: fetches WorkDays and delegates to `ShiftExportService`. Rows are
    /// sorted by date ascending and multiple task codes are joined deterministically
    /// (`MW;Ticket`). Resolved times are never included. WorkDays are never modified.
    ///
    /// - Returns: The CSV text content, or nil if an error occurred (see `errorMessage`).
    public func makeExportContent() -> String? {
        do {
            let workDays = try fetchAllWorkDays()
            let result = exportService.export(workDays: workDays, taskService: taskService)
            return result.textContent
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return nil
        }
    }

    /// Number of WorkDays that would be exported (for UI display).
    public func exportableWorkDayCount() -> Int {
        (try? fetchAllWorkDays().count) ?? 0
    }

    // MARK: - Template

    /// Generates the empty official CSV template (header only).
    ///
    /// Prefers the existing `ShiftTemplate` implementation via the export service.
    public func makeTemplateContent() -> String {
        exportService.generateEmptyTemplate()
    }

    // MARK: - Import

    /// Supported import file extensions for this task (CSV only; .txt allowed as text CSV).
    public static let supportedImportExtensions: Set<String> = ["csv", "txt"]

    /// Whether a file extension is a supported CSV/text file.
    public static func isSupportedImportExtension(_ ext: String) -> Bool {
        supportedImportExtensions.contains(ext.lowercased())
    }

    /// Parses and validates CSV text, producing a preview for user review.
    ///
    /// Nothing is persisted. Delegates to the existing `ShiftImportService`.
    /// On failure, sets a Vietnamese `errorMessage` and clears the preview.
    ///
    /// - Parameter content: The raw CSV text content.
    /// - Returns: true if a preview was produced.
    @discardableResult
    public func prepareImport(content: String) -> Bool {
        errorMessage = nil
        lastResult = nil
        do {
            let preview = try importService.prepareImport(content: content)
            self.preview = preview
            return true
        } catch {
            self.preview = nil
            self.errorMessage = importErrorMessage(for: error)
            return false
        }
    }

    /// Parses and validates a CSV file at the given URL.
    ///
    /// Rejects unsupported extensions with the CSV-only message before parsing.
    ///
    /// - Parameter url: The picked file URL (.csv or .txt).
    /// - Returns: true if a preview was produced.
    @discardableResult
    public func prepareImport(url: URL) -> Bool {
        errorMessage = nil
        lastResult = nil

        guard Self.isSupportedImportExtension(url.pathExtension) else {
            self.preview = nil
            self.errorMessage = "Chỉ hỗ trợ file CSV."
            return false
        }

        do {
            let preview = try importService.prepareImport(url: url)
            self.preview = preview
            return true
        } catch {
            self.preview = nil
            self.errorMessage = importErrorMessage(for: error)
            return false
        }
    }

    // MARK: - Import Confirmation Summary

    /// Number of new WorkDays that will be added (valid, non-OFF, non-conflict rows).
    public var willAddCount: Int {
        guard let preview = preview else { return 0 }
        return preview.validRows.count
    }

    /// Number of existing WorkDays that will be updated (only when replacing).
    public var willUpdateCount: Int {
        guard let preview = preview else { return 0 }
        switch conflictStrategy {
        case .replaceExisting:
            // Conflict rows that are not OFF become updates; OFF conflicts become deletions.
            return preview.conflictRows.filter { !$0.isOff }.count
        case .skipExisting:
            return 0
        }
    }

    /// Number of rows that will be skipped (conflicts when skipping).
    public var willSkipCount: Int {
        guard let preview = preview else { return 0 }
        switch conflictStrategy {
        case .skipExisting:
            return preview.conflictRows.count
        case .replaceExisting:
            return 0
        }
    }

    /// Number of rows that are errors and will never be imported.
    public var errorCount: Int {
        (preview?.errorRows.count ?? 0) + (preview?.duplicateRows.count ?? 0)
    }

    /// Number of OFF rows (create no WorkDay).
    public var offCount: Int {
        preview?.offRows.count ?? 0
    }

    // MARK: - Execute Import

    /// Executes the import using the current preview and conflict strategy.
    ///
    /// Only valid rows are imported. Invalid/duplicate rows are never imported.
    /// Delegates to `ShiftImportService.executeImport`, which drives WorkDayService
    /// (and therefore ShiftResolver + widget refresh). On success, stores the result.
    ///
    /// - Returns: the ImportResult, or nil on failure (see `errorMessage`).
    @discardableResult
    public func executeImport() -> ImportResult? {
        guard let preview = preview else {
            errorMessage = "Không có dữ liệu để nhập."
            return nil
        }

        isBusy = true
        defer { isBusy = false }

        do {
            // For "replace" of OFF conflict rows: delete the existing WorkDay so the
            // day becomes OFF. ShiftImportService does not delete on OFF, so we handle
            // OFF-replace here (still through WorkDayService — no snapshot rewrite).
            if conflictStrategy == .replaceExisting {
                try deleteExistingForOffConflicts(in: preview)
            }

            let result = try importService.executeImport(
                preview: preview,
                strategy: conflictStrategy
            )
            self.lastResult = result
            self.errorMessage = nil
            return result
        } catch {
            self.errorMessage = UserFacingError.message(for: error)
            return nil
        }
    }

    /// Clears the current preview/result state (e.g., when leaving the flow).
    public func reset() {
        preview = nil
        lastResult = nil
        errorMessage = nil
        conflictStrategy = .skipExisting
    }

    // MARK: - Private Helpers

    /// Fetches all WorkDays across a wide range for export.
    ///
    /// Uses a broad date window so all stored WorkDays are included. This is a
    /// read-only fetch — no resolution or mutation occurs.
    private func fetchAllWorkDays() throws -> [WorkDay] {
        let now = Date()
        // Wide window: 5 years back, 5 years forward. Personal-schedule scale.
        let start = calendar.date(byAdding: .year, value: -5, to: now) ?? now
        let end = calendar.date(byAdding: .year, value: 5, to: now) ?? now
        return try workDayService.fetchWorkDays(from: start, to: end)
    }

    /// Deletes existing WorkDays for OFF rows when the user chose to replace.
    /// OFF means absence of a WorkDay, so replacing an existing day with OFF
    /// removes it. Never creates an OFF ShiftDefinition/WorkDay.
    private func deleteExistingForOffConflicts(in preview: ImportPreview) throws {
        for row in preview.conflictRows where row.isOff {
            guard let date = row.date else { continue }
            if let existing = try workDayService.fetchWorkDay(date: date) {
                try workDayService.deleteWorkDay(id: existing.id)
            }
        }
    }

    /// Maps an import error to a Vietnamese message, preferring the CSV-only
    /// message for unsupported formats in this CSV-focused flow.
    private func importErrorMessage(for error: Error) -> String {
        if let parseError = error as? ImportParseError {
            switch parseError {
            case .emptyFile:
                return "File không có dữ liệu."
            case .invalidHeader:
                return "Cần các cột: Date, Shift, Task, Note."
            case .unsupportedFormat:
                return "Chỉ hỗ trợ file CSV."
            case .readFailed:
                return "Không thể đọc tệp. Vui lòng thử lại."
            }
        }
        return UserFacingError.message(for: error)
    }
}
