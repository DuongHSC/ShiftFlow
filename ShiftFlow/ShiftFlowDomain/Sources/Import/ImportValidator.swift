// ShiftFlow — Domain Layer
// Import/ImportValidator.swift
//
// TASK-IMPORT-001: Import validation logic.
//
// Validates parsed raw rows and produces validated rows with status.
// Detects:
// - Missing/invalid dates
// - Invalid shift codes
// - Duplicate dates within the file
// - Existing WorkDay conflicts
//
// The validator does NOT contain shift-resolution logic.
// It only checks that values are structurally valid.

import Foundation

/// Validates parsed import rows and detects errors/conflicts.
public enum ImportValidator {

    /// Valid shift codes accepted by the importer.
    public static let validShiftCodes: Set<String> = ["C1", "C2", "C3", "C4", "C5", "OFF"]

    /// Date format expected in the Excel export.
    private static let dateFormat = "dd/MM/yyyy"

    /// Validates an array of raw parsed rows.
    ///
    /// - Parameters:
    ///   - rows: Raw rows from the parser.
    ///   - existingWorkDayDates: Set of normalized dates that already have WorkDays.
    ///   - calendar: Calendar for date operations.
    /// - Returns: Array of validated rows with status.
    public static func validate(
        rows: [ImportRawRow],
        existingWorkDayDates: Set<Date>,
        calendar: Calendar = .current,
        knownTaskCodes: Set<String> = []
    ) -> [ImportValidatedRow] {

        // Uppercased known task codes for case-insensitive validation.
        let knownUpper = Set(knownTaskCodes.map { $0.uppercased() })

        // First pass: parse and validate each row individually.
        var parsed: [(row: ImportRawRow, date: Date?, shiftCode: String?, task: String?, note: String?, error: String?)] = []

        for row in rows {
            let (date, dateError) = parseDate(row.dateString, calendar: calendar)
            let (shiftCode, shiftError) = parseShiftCode(row.shiftString)

            // Task validation (only when known codes are supplied).
            var taskError: String? = nil
            if !knownUpper.isEmpty, let taskString = row.taskString, !taskString.isEmpty {
                let codes = taskString
                    .split(separator: ";")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                for code in codes where !knownUpper.contains(code.uppercased()) {
                    taskError = "Task không hợp lệ: \(code)"
                    break
                }
            }

            let error = dateError ?? shiftError ?? taskError
            let task = row.taskString
            let note = row.noteString

            parsed.append((row: row, date: date, shiftCode: shiftCode, task: task, note: note, error: error))
        }

        // Second pass: detect duplicate dates within the file.
        var dateCounts: [Date: [Int]] = [:]
        for (index, item) in parsed.enumerated() {
            if let date = item.date {
                let normalized = calendar.startOfDay(for: date)
                dateCounts[normalized, default: []].append(index)
            }
        }

        let duplicateDateIndices: Set<Int> = {
            var indices = Set<Int>()
            for (_, rowIndices) in dateCounts where rowIndices.count > 1 {
                for idx in rowIndices {
                    indices.insert(idx)
                }
            }
            return indices
        }()

        // Third pass: build validated rows with final status.
        var results: [ImportValidatedRow] = []

        for (index, item) in parsed.enumerated() {
            let status: ImportRowStatus

            if let error = item.error {
                status = .error(error)
            } else if duplicateDateIndices.contains(index) {
                let dateStr = item.row.dateString ?? "unknown"
                status = .duplicateInFile("Duplicate date \(dateStr) in file")
            } else if let date = item.date {
                let normalized = calendar.startOfDay(for: date)
                if existingWorkDayDates.contains(normalized) {
                    status = .conflict("Existing WorkDay for this date")
                } else {
                    status = .valid
                }
            } else {
                status = .error("Unknown validation error")
            }

            results.append(ImportValidatedRow(
                rowNumber: item.row.rowNumber,
                date: item.date,
                shiftCode: item.shiftCode,
                task: item.task,
                note: item.note,
                status: status
            ))
        }

        return results
    }

    // MARK: - Private Helpers

    /// Parses a date string in DD/MM/YYYY format.
    private static func parseDate(
        _ dateString: String?,
        calendar: Calendar
    ) -> (Date?, String?) {
        guard let dateString = dateString, !dateString.isEmpty else {
            return (nil, "Missing date")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.calendar = calendar
        // Parse in the SAME time zone as the calendar so the resulting date-only
        // value matches how export/WorkDay produce it (symmetric round-trip).
        // Without this, DateFormatter uses the system time zone and midnight in
        // the app's time zone would map to a different calendar day.
        formatter.timeZone = calendar.timeZone
        formatter.isLenient = false

        guard let date = formatter.date(from: dateString) else {
            return (nil, "Invalid date format '\(dateString)' (expected DD/MM/YYYY)")
        }

        return (calendar.startOfDay(for: date), nil)
    }

    /// Parses and validates a shift code string.
    private static func parseShiftCode(_ shiftString: String?) -> (String?, String?) {
        guard let shiftString = shiftString, !shiftString.isEmpty else {
            return (nil, "Missing shift")
        }

        let normalized = shiftString.uppercased().trimmingCharacters(in: .whitespaces)

        guard validShiftCodes.contains(normalized) else {
            return (nil, "Invalid shift '\(shiftString)'")
        }

        return (normalized, nil)
    }
}
