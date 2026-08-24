// ShiftFlow — Domain Layer
// Models/ImportModels.swift
//
// TASK-IMPORT-001: Import and Export data models.
//
// These models represent the parsed, validated, and previewed state
// of a shift schedule import/export operation.
//
// OFFICIAL FORMAT: Excel .xlsx
// The official ShiftFlow import/export format is .xlsx (Excel spreadsheet).
// CSV (comma/tab/pipe/semicolon delimited) is supported as a secondary
// text-based interchange format for parsing.
//
// IMPORTANT:
// - Import models do NOT contain shift-resolution logic.
// - ShiftResolver remains the single source of truth.
// - Tasks/Notes do NOT influence shift times.
// - OFF is NOT a persistent ShiftDefinition.
// - Export does NOT expose resolved start/end/break as user-editable columns.

import Foundation

// MARK: - Parsed Row

/// Represents a single row parsed from the Excel import file.
/// Contains raw string values before validation.
public struct ImportRawRow: Equatable, Sendable {
    /// 1-based row number in the source file.
    public let rowNumber: Int

    /// Raw date string (expected format: DD/MM/YYYY).
    public let dateString: String?

    /// Raw shift code string (e.g., "C1", "C5", "OFF").
    public let shiftString: String?

    /// Raw task string (optional, e.g., "MW", "Zalo").
    public let taskString: String?

    /// Raw note string (optional, free text).
    public let noteString: String?

    public init(
        rowNumber: Int,
        dateString: String?,
        shiftString: String?,
        taskString: String?,
        noteString: String?
    ) {
        self.rowNumber = rowNumber
        self.dateString = dateString
        self.shiftString = shiftString
        self.taskString = taskString
        self.noteString = noteString
    }
}

// MARK: - Validated Row

/// The validation status of a single import row.
public enum ImportRowStatus: Equatable, Sendable {
    /// Row is valid and ready for import.
    case valid
    /// Row has an existing WorkDay conflict.
    case conflict(String)
    /// Row has a validation error and cannot be imported.
    case error(String)
    /// Row is a duplicate date within the same file.
    case duplicateInFile(String)
}

/// A validated import row with parsed values and status.
public struct ImportValidatedRow: Equatable, Sendable {
    /// 1-based row number in the source file.
    public let rowNumber: Int

    /// Parsed date (nil if parsing failed).
    public let date: Date?

    /// Parsed shift code (nil if parsing failed).
    /// "OFF" is a valid value here but means no WorkDay should be created.
    public let shiftCode: String?

    /// Parsed task name (optional).
    public let task: String?

    /// Parsed note text (optional).
    public let note: String?

    /// Validation status.
    public let status: ImportRowStatus

    /// Whether this row represents OFF (no work scheduled).
    public var isOff: Bool {
        shiftCode?.uppercased() == "OFF"
    }

    /// Whether this row is importable (valid and not OFF).
    public var isImportable: Bool {
        if case .valid = status {
            return !isOff
        }
        return false
    }

    public init(
        rowNumber: Int,
        date: Date?,
        shiftCode: String?,
        task: String?,
        note: String?,
        status: ImportRowStatus
    ) {
        self.rowNumber = rowNumber
        self.date = date
        self.shiftCode = shiftCode
        self.task = task
        self.note = note
        self.status = status
    }
}

// MARK: - Import Preview

/// Summary of the import validation/preview before user confirmation.
public struct ImportPreview: Equatable, Sendable {
    /// All validated rows.
    public let rows: [ImportValidatedRow]

    /// Total number of rows parsed.
    public var totalRows: Int { rows.count }

    /// Rows that are valid and importable (excluding OFF).
    public var validRows: [ImportValidatedRow] {
        rows.filter { $0.isImportable }
    }

    /// Rows representing OFF (valid but no WorkDay created).
    public var offRows: [ImportValidatedRow] {
        rows.filter { $0.isOff && $0.status == .valid }
    }

    /// Rows with validation errors.
    public var errorRows: [ImportValidatedRow] {
        rows.filter {
            if case .error = $0.status { return true }
            return false
        }
    }

    /// Rows with duplicate dates within the file.
    public var duplicateRows: [ImportValidatedRow] {
        rows.filter {
            if case .duplicateInFile = $0.status { return true }
            return false
        }
    }

    /// Rows with existing WorkDay conflicts.
    public var conflictRows: [ImportValidatedRow] {
        rows.filter {
            if case .conflict = $0.status { return true }
            return false
        }
    }

    /// Whether the import can proceed (at least one valid row, no blocking errors).
    public var canImport: Bool {
        !validRows.isEmpty
    }

    /// Whether there are any issues (errors, duplicates, or conflicts).
    public var hasIssues: Bool {
        !errorRows.isEmpty || !duplicateRows.isEmpty || !conflictRows.isEmpty
    }

    public init(rows: [ImportValidatedRow]) {
        self.rows = rows
    }
}

// MARK: - Conflict Resolution Strategy

/// Strategy for handling existing WorkDay conflicts during import.
public enum ImportConflictStrategy: Equatable, Sendable {
    /// Skip rows that conflict with existing WorkDays.
    case skipExisting
    /// Replace existing WorkDays with imported data.
    case replaceExisting
}

// MARK: - Import Result

/// The result of a confirmed import operation.
public struct ImportResult: Equatable, Sendable {
    /// Number of WorkDays created.
    public let created: Int
    /// Number of existing WorkDays replaced/updated.
    public let replaced: Int
    /// Number of rows skipped (conflicts with skipExisting strategy).
    public let skipped: Int
    /// Number of OFF rows (no WorkDay created intentionally).
    public let offDays: Int
    /// Total rows processed.
    public var total: Int { created + replaced + skipped + offDays }

    public init(created: Int, replaced: Int, skipped: Int, offDays: Int) {
        self.created = created
        self.replaced = replaced
        self.skipped = skipped
        self.offDays = offDays
    }
}

// MARK: - Parse Error

/// Errors that can occur during file parsing.
public enum ImportParseError: Error, Equatable {
    case emptyFile
    case invalidHeader
    case unsupportedFormat
    case readFailed(String)
}

// MARK: - Supported File Formats

/// Supported file formats for ShiftFlow import/export.
public enum ShiftFileFormat: String, CaseIterable, Sendable {
    /// Official Excel format (.xlsx). Primary supported format.
    case xlsx = "xlsx"
    /// CSV text format. Secondary interchange format for text-based parsing.
    case csv = "csv"

    /// The official/primary format for ShiftFlow import/export.
    public static let official: ShiftFileFormat = .xlsx

    /// File extension including the dot.
    public var fileExtension: String {
        ".\(rawValue)"
    }

    /// MIME type for the format.
    public var mimeType: String {
        switch self {
        case .xlsx:
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .csv:
            return "text/csv"
        }
    }
}

// MARK: - Export Row

/// Represents a single row in an exported shift schedule file.
///
/// Export format: Date | Shift | Task | Note
/// Export does NOT include resolved start/end/break times.
/// Shift times are derived from ShiftResolver and are not user-entered data.
public struct ExportRow: Equatable, Sendable {
    /// Formatted date string (DD/MM/YYYY).
    public let dateString: String

    /// Shift code (e.g., "C1", "C5").
    public let shiftCode: String

    /// Task name (may be empty string).
    public let task: String

    /// Note text (may be empty string).
    public let note: String

    public init(dateString: String, shiftCode: String, task: String, note: String) {
        self.dateString = dateString
        self.shiftCode = shiftCode
        self.task = task
        self.note = note
    }
}

// MARK: - Export Result

/// The result of an export operation.
public struct ExportResult: Equatable, Sendable {
    /// The exported rows (header excluded).
    public let rows: [ExportRow]

    /// The full text content (header + rows) in CSV format.
    /// For .xlsx, this content is used as the data source for spreadsheet generation.
    public let textContent: String

    /// Number of WorkDays exported.
    public var count: Int { rows.count }

    public init(rows: [ExportRow], textContent: String) {
        self.rows = rows
        self.textContent = textContent
    }
}

// MARK: - Template

/// The official ShiftFlow Excel template structure.
public enum ShiftTemplate {

    /// Official column headers.
    public static let headers: [String] = ["Date", "Shift", "Task", "Note"]

    /// Date format used in the template.
    public static let dateFormat = "dd/MM/yyyy"

    /// Example rows for the template.
    public static let exampleRows: [[String]] = [
        ["01/08/2026", "C1", "", ""],
        ["02/08/2026", "C5", "MW", "Trực MW"],
        ["03/08/2026", "C3", "Zalo", ""],
        ["04/08/2026", "OFF", "", "Nghỉ"],
        ["05/08/2026", "C5", "Ticket", "Chuyển ticket"],
    ]

    /// Generates the template as CSV text content.
    /// This serves as the data source for both CSV files and XLSX generation.
    public static func generateTemplateContent(includeExamples: Bool = true) -> String {
        var lines: [String] = []
        lines.append(headers.joined(separator: ","))

        if includeExamples {
            for row in exampleRows {
                lines.append(row.joined(separator: ","))
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Generates an empty template (header only) as CSV text.
    public static func generateEmptyTemplate() -> String {
        headers.joined(separator: ",")
    }
}

