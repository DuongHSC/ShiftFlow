// ShiftFlow — UI Layer
// Settings/CSVImportPreviewView.swift
//
// TASK-DATA-001: Import preview + confirmation (Settings → Dữ liệu → Nhập dữ liệu).
//
// Shows a summary and per-row status before any data is persisted. The user
// chooses a conflict strategy (default: Bỏ qua / skip — no silent overwrite),
// confirms, and the import executes via DataManagementViewModel (existing
// ShiftImportService → WorkDayService → ShiftResolver). Result is shown after.

import SwiftUI
import ShiftFlowDomain

struct CSVImportPreviewView: View {
    @Bindable var viewModel: DataManagementViewModel
    let preview: ImportPreview

    @Environment(\.dismiss) private var dismiss

    @State private var showConfirm = false
    @State private var showResult = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    var body: some View {
        List {
            summarySection
            conflictSection
            rowsSection
            importButtonSection
        }
        .navigationTitle("Xem trước")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Nhập dữ liệu?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Nhập dữ liệu") {
                if viewModel.executeImport() != nil {
                    showResult = true
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text(confirmSummaryText)
        }
        .alert("Nhập dữ liệu hoàn tất", isPresented: $showResult) {
            Button("OK") { dismiss() }
        } message: {
            Text(resultSummaryText)
        }
        .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil && !showResult)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section("Tổng quan") {
            summaryRow("Tổng số dòng", value: preview.totalRows)
            summaryRow("Dòng hợp lệ", value: preview.validRows.count)
            summaryRow("OFF", value: preview.offRows.count)
            summaryRow("Dòng lỗi", value: preview.errorRows.count)
            summaryRow("Trùng ngày trong file", value: preview.duplicateRows.count)
            summaryRow("Ngày đã tồn tại", value: preview.conflictRows.count)
        }
    }

    private func summaryRow(_ title: String, value: Int) -> some View {
        LabeledContent(title, value: "\(value)")
            .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Conflict Strategy

    @ViewBuilder
    private var conflictSection: some View {
        if !preview.conflictRows.isEmpty {
            Section {
                Picker("Ngày đã tồn tại", selection: $viewModel.conflictStrategy) {
                    Text("Bỏ qua").tag(ImportConflictStrategy.skipExisting)
                    Text("Ghi đè").tag(ImportConflictStrategy.replaceExisting)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(viewModel.conflictStrategy == .skipExisting
                                    ? "Bỏ qua ngày đã tồn tại"
                                    : "Ghi đè ngày đã tồn tại")
            } header: {
                Text("Xử lý ngày đã tồn tại")
            } footer: {
                Text("Mặc định là Bỏ qua. Chọn Ghi đè để cập nhật ngày đã có.")
            }
        }
    }

    // MARK: - Rows

    private var rowsSection: some View {
        Section("Chi tiết") {
            ForEach(preview.rows, id: \.rowNumber) { row in
                rowView(row)
            }
        }
    }

    private func rowView(_ row: ImportValidatedRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(statusSymbol(row))
                .font(.headline)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(dateText(row))
                        .font(.subheadline).fontWeight(.medium)
                    Text(row.shiftCode ?? "—")
                        .font(.subheadline)
                        .foregroundStyle(ShiftStyle.foregroundColor(for: row.shiftCode ?? ""))
                }
                if let task = row.task, !task.isEmpty {
                    Text("Công việc: \(task)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let note = row.note, !note.isEmpty {
                    Text("Ghi chú: \(note)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(statusText(row))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel(row))
    }

    // MARK: - Import Button

    private var importButtonSection: some View {
        Section {
            Button {
                showConfirm = true
            } label: {
                Text("Nhập dữ liệu")
            }
            .disabled(!preview.canImport && viewModel.willUpdateCount == 0)
            .accessibilityLabel("Xác nhận nhập dữ liệu")
        } footer: {
            if !preview.canImport && viewModel.willUpdateCount == 0 {
                Text("Không có dòng hợp lệ để nhập.")
            }
        }
    }

    // MARK: - Status Presentation (never color-only)

    private func statusSymbol(_ row: ImportValidatedRow) -> String {
        if row.isOff { return "○" }
        switch row.status {
        case .valid: return "✓"
        case .conflict: return "⚠"
        case .error: return "✕"
        case .duplicateInFile: return "✕"
        }
    }

    private func statusText(_ row: ImportValidatedRow) -> String {
        if row.isOff { return "OFF" }
        switch row.status {
        case .valid: return "Hợp lệ"
        case .conflict: return "Đã tồn tại"
        case .error(let msg): return localizedError(msg)
        case .duplicateInFile: return "Trùng ngày trong file"
        }
    }

    private func dateText(_ row: ImportValidatedRow) -> String {
        if let date = row.date { return dateFormatter.string(from: date) }
        return "Ngày ?"
    }

    private func rowAccessibilityLabel(_ row: ImportValidatedRow) -> String {
        var parts: [String] = ["Dòng \(row.rowNumber)"]
        parts.append(dateText(row))
        if let code = row.shiftCode { parts.append("Ca \(code)") }
        if let task = row.task, !task.isEmpty { parts.append("Công việc \(task)") }
        parts.append(statusText(row))
        return parts.joined(separator: ", ")
    }

    /// Converts internal English validator errors to friendly Vietnamese where possible.
    private func localizedError(_ raw: String) -> String {
        if raw.hasPrefix("Task không hợp lệ") { return raw }
        if raw.contains("Invalid date") { return "Ngày không hợp lệ." }
        if raw.contains("Missing date") { return "Ngày không hợp lệ." }
        if raw.contains("Invalid shift") { return "Ca làm việc không hợp lệ." }
        if raw.contains("Missing shift") { return "Ca làm việc không hợp lệ." }
        return "Dòng không hợp lệ."
    }

    // MARK: - Confirm / Result Summary Text

    private var confirmSummaryText: String {
        """
        \(viewModel.willAddCount) ngày sẽ được thêm
        \(viewModel.willUpdateCount) ngày sẽ được cập nhật
        \(viewModel.willSkipCount) ngày sẽ bị bỏ qua
        \(viewModel.errorCount) dòng lỗi
        """
    }

    private var resultSummaryText: String {
        guard let r = viewModel.lastResult else { return "" }
        return """
        Đã thêm: \(r.created)
        Đã cập nhật: \(r.replaced)
        Đã bỏ qua: \(r.skipped)
        OFF: \(r.offDays)
        Lỗi: \(viewModel.errorCount)
        """
    }
}
