// ShiftFlow — UI Layer
// Settings/CSVFileWriter.swift
//
// TASK-DATA-001: Small helper to materialize CSV text into a temporary file
// so it can be shared via the native iOS share sheet (ShareLink).
//
// This is a UI-support utility only. It performs no parsing, validation, or
// shift resolution. It writes UTF-8 text (Excel-compatible CSV) to a temp file.

import Foundation

/// Writes CSV text content to a temporary file and returns its URL.
enum CSVFileWriter {

    /// Writes `content` to a temporary file named `fileName`.
    ///
    /// - Parameters:
    ///   - content: The CSV text content.
    ///   - fileName: The desired file name (e.g., `ShiftFlow_2026-08-24.csv`).
    /// - Returns: A file URL in the temporary directory.
    /// - Throws: If the file cannot be written.
    static func write(content: String, fileName: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(fileName)
        // UTF-8 BOM improves Excel compatibility for non-ASCII text on some platforms.
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
