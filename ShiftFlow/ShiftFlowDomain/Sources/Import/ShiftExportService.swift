// ShiftFlow — Domain Layer
// Import/ShiftExportService.swift
//
// TASK-IMPORT-001: Export service for WorkDay data.
//
// Exports existing WorkDays to the official ShiftFlow Excel template format.
//
// Export format (columns):
//   Date | Shift | Task | Note
//
// CRITICAL RULES:
// - Export does NOT include resolved start/end/break times as columns.
//   Shift times are derived from ShiftResolver and are not user-entered data.
// - Export does NOT modify WorkDays. It is a read-only operation.
// - Export does NOT recalculate historical snapshot values.
// - Export uses the WorkDay's stored shiftCode for the Shift column.
//
// The exported file can be re-imported via ShiftImportService, completing
// the round-trip: WorkDay → Export → Import → WorkDay.

import Foundation

/// Service that exports WorkDay data to the official ShiftFlow template format.
///
/// Usage:
/// ```swift
/// let service = ShiftExportService(calendar: calendar)
/// let result = service.export(workDays: workDays)
/// // result.textContent contains the CSV representation
/// // For .xlsx, pass result to an XLSX writer adapter
/// ```
public final class ShiftExportService {

    private let calendar: Calendar
    private let dateFormatter: DateFormatter

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = ShiftTemplate.dateFormat
        self.dateFormatter.calendar = calendar
        // Format the date in the SAME time zone as the calendar that produced it.
        // WorkDay.date is a startOfDay value in `calendar`'s time zone; without
        // this, DateFormatter uses the system time zone (e.g. UTC on CI) and a
        // local-midnight date renders as the previous calendar day. Aligning the
        // time zone keeps the date-only value stable across export/import/sort/
        // round-trip. No offset hacks, no dependence on the machine time zone.
        self.dateFormatter.timeZone = calendar.timeZone
    }

    // MARK: - Export WorkDays

    /// Exports an array of WorkDays to the official template format.
    ///
    /// The export produces:
    /// - `ExportRow` array (structured data for each WorkDay)
    /// - `textContent` (CSV-formatted string with header, suitable for file writing or XLSX generation)
    ///
    /// WorkDays are sorted by date ascending in the output.
    ///
    /// - Parameter workDays: The WorkDays to export.
    /// - Returns: An `ExportResult` containing rows and text content.
    public func export(workDays: [WorkDay]) -> ExportResult {
        // Sort by date ascending.
        let sorted = workDays.sorted { $0.date < $1.date }

        // Map to export rows.
        let rows: [ExportRow] = sorted.map { workDay in
            ExportRow(
                dateString: dateFormatter.string(from: workDay.date),
                shiftCode: workDay.shiftCode,
                task: "", // Task export will be added when Tasks are implemented
                note: workDay.note ?? ""
            )
        }

        // Build CSV text content.
        let textContent = buildTextContent(rows: rows)

        return ExportResult(rows: rows, textContent: textContent)
    }

    /// Exports WorkDays with their associated task names.
    ///
    /// - Parameters:
    ///   - workDays: The WorkDays to export.
    ///   - taskLookup: Closure that returns the task name string for a given WorkDay ID.
    ///     Returns nil or empty string if no task is assigned.
    /// - Returns: An `ExportResult`.
    public func export(
        workDays: [WorkDay],
        taskLookup: (UUID) -> String?
    ) -> ExportResult {
        let sorted = workDays.sorted { $0.date < $1.date }

        let rows: [ExportRow] = sorted.map { workDay in
            ExportRow(
                dateString: dateFormatter.string(from: workDay.date),
                shiftCode: workDay.shiftCode,
                task: taskLookup(workDay.id) ?? "",
                note: workDay.note ?? ""
            )
        }

        let textContent = buildTextContent(rows: rows)

        return ExportResult(rows: rows, textContent: textContent)
    }

    /// Exports WorkDays with their tasks resolved via a TaskService.
    ///
    /// Multiple tasks are represented deterministically as `CODE1;CODE2` (sorted by code).
    /// Export is read-only and does NOT include resolved times.
    ///
    /// - Parameters:
    ///   - workDays: The WorkDays to export.
    ///   - taskService: Provides task assignments per WorkDay.
    /// - Returns: An `ExportResult`.
    public func export(
        workDays: [WorkDay],
        taskService: TaskService
    ) -> ExportResult {
        export(workDays: workDays) { workDayID in
            let codes = taskService.tasks(forWorkDay: workDayID)
                .map { $0.code }
                .sorted()
            return codes.isEmpty ? nil : codes.joined(separator: ";")
        }
    }

    // MARK: - Template Generation

    /// Generates the official ShiftFlow Excel template content.
    ///
    /// The template includes:
    /// - Header row: Date, Shift, Task, Note
    /// - Example rows demonstrating the expected format
    ///
    /// This content can be written to a .csv file or used as the data source
    /// for XLSX generation via a platform-specific adapter.
    ///
    /// - Parameter includeExamples: Whether to include example rows. Defaults to true.
    /// - Returns: Template text content in CSV format.
    public func generateTemplate(includeExamples: Bool = true) -> String {
        ShiftTemplate.generateTemplateContent(includeExamples: includeExamples)
    }

    /// Generates an empty template (header only, no example data).
    public func generateEmptyTemplate() -> String {
        ShiftTemplate.generateEmptyTemplate()
    }

    // MARK: - Private Helpers

    /// Builds the full CSV text content from export rows.
    private func buildTextContent(rows: [ExportRow]) -> String {
        var lines: [String] = []

        // Header.
        lines.append(ShiftTemplate.headers.joined(separator: ","))

        // Data rows.
        for row in rows {
            let escapedNote = escapeCSVField(row.note)
            let escapedTask = escapeCSVField(row.task)
            lines.append("\(row.dateString),\(row.shiftCode),\(escapedTask),\(escapedNote)")
        }

        return lines.joined(separator: "\n")
    }

    /// Escapes a CSV field value (wraps in quotes if it contains comma or newline).
    private func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
