// ShiftFlow — Domain Layer
// Import/ShiftFileParser.swift
//
// TASK-IMPORT-001: File parser for shift schedule import.
//
// OFFICIAL FORMAT: Excel .xlsx
// ShiftFlow's official import/export format is .xlsx (Excel spreadsheet).
//
// PARSING STRATEGY:
// The parser operates on text-based content (CSV/tab/pipe/semicolon delimited).
// For .xlsx files, a higher-level adapter extracts the text content from
// the spreadsheet and passes it to this parser. The .xlsx adapter requires
// a platform-specific library (e.g., CoreXLSX on Apple platforms) and will
// be integrated during macOS/Xcode build verification.
//
// This text parser handles the extracted tabular data regardless of whether
// it originated from .xlsx extraction or a direct CSV file.
//
// The parser does NOT validate business logic — that is the validator's job.
// The parser only extracts raw string values from the file structure.

import Foundation

/// Parses a shift schedule file into raw import rows.
///
/// This parser handles text-based tabular content. For .xlsx files,
/// the content should first be extracted by an XLSX adapter and then
/// passed to `parse(content:)`.
public enum ShiftFileParser {

    /// Expected header variations (case-insensitive).
    private static let expectedDateHeaders: Set<String> = ["date", "ngày", "ngay"]
    private static let expectedShiftHeaders: Set<String> = ["shift", "ca"]

    /// Supported delimiters (tried in order).
    private static let delimiters: [Character] = [",", "\t", "|", ";"]

    /// Parses a file at the given URL into raw import rows.
    ///
    /// For .xlsx files: Requires platform-specific XLSX adapter (pending macOS integration).
    /// For .csv files: Reads text content directly.
    ///
    /// - Parameter url: URL to the import file (.xlsx or .csv).
    /// - Returns: Array of `ImportRawRow` (one per data row, excluding header).
    /// - Throws: `ImportParseError` if the file cannot be read or has an invalid structure.
    public static func parse(url: URL) throws -> [ImportRawRow] {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "xlsx":
            // XLSX parsing requires a platform-specific adapter.
            // On Apple platforms, this would use CoreXLSX or similar.
            // For now, throw unsupportedFormat if no adapter is available.
            // The XLSX adapter will extract text content and call parse(content:).
            throw ImportParseError.unsupportedFormat
        case "csv", "tsv", "txt":
            let content: String
            do {
                content = try String(contentsOf: url, encoding: .utf8)
            } catch {
                throw ImportParseError.readFailed(error.localizedDescription)
            }
            return try parse(content: content)
        default:
            throw ImportParseError.unsupportedFormat
        }
    }

    /// Parses text content directly (for testing without file system).
    ///
    /// - Parameter content: The full text content of the import file.
    /// - Returns: Array of `ImportRawRow`.
    /// - Throws: `ImportParseError` if the content is empty or has invalid header.
    public static func parse(content: String) throws -> [ImportRawRow] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportParseError.emptyFile
        }

        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw ImportParseError.emptyFile
        }

        // Detect delimiter from the first line (header).
        let headerLine = lines[0]
        guard let delimiter = detectDelimiter(headerLine) else {
            throw ImportParseError.invalidHeader
        }

        // Validate header.
        let headerColumns = splitLine(headerLine, delimiter: delimiter)
        guard isValidHeader(headerColumns) else {
            throw ImportParseError.invalidHeader
        }

        // Parse data rows.
        var rows: [ImportRawRow] = []
        for (index, line) in lines.dropFirst().enumerated() {
            let rowNumber = index + 2 // 1-based, header is row 1
            let columns = splitLine(line, delimiter: delimiter)

            let dateString = columns.count > 0 ? normalizeCell(columns[0]) : nil
            let shiftString = columns.count > 1 ? normalizeCell(columns[1]) : nil
            let taskString = columns.count > 2 ? normalizeCell(columns[2]) : nil
            let noteString = columns.count > 3 ? normalizeCell(columns[3]) : nil

            rows.append(ImportRawRow(
                rowNumber: rowNumber,
                dateString: dateString,
                shiftString: shiftString,
                taskString: taskString,
                noteString: noteString
            ))
        }

        return rows
    }

    // MARK: - Private Helpers

    /// Detects the delimiter used in a line.
    private static func detectDelimiter(_ line: String) -> Character? {
        for delimiter in delimiters {
            if line.contains(delimiter) {
                return delimiter
            }
        }
        return nil
    }

    /// Splits a line by the given delimiter, trimming whitespace from each cell.
    private static func splitLine(_ line: String, delimiter: Character) -> [String] {
        line.split(separator: delimiter, omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    /// Validates that the header contains expected column names.
    private static func isValidHeader(_ columns: [String]) -> Bool {
        guard columns.count >= 2 else { return false }

        let first = columns[0].lowercased().trimmingCharacters(in: .whitespaces)
        let second = columns[1].lowercased().trimmingCharacters(in: .whitespaces)

        let hasDate = expectedDateHeaders.contains(first)
        let hasShift = expectedShiftHeaders.contains(second)

        return hasDate && hasShift
    }

    /// Normalizes a cell value: returns nil if empty after trimming.
    private static func normalizeCell(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
