// ShiftFlow — UI Layer
// Calendar/DayDetailSheet.swift
//
// TASK-CALENDAR-001: Day Detail view/edit sheet.
//
// Displays WorkDay details and allows editing.
// Shift selection triggers ShiftResolver via DayDetailViewModel.
// Does NOT contain shift-calculation logic.

import SwiftUI
import ShiftFlowDomain

struct DayDetailSheet: View {
    @Bindable var viewModel: DayDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let shiftCodes = ["C1", "C2", "C3", "C4", "C5", "OFF"]
    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                shiftSection
                if viewModel.selectedShiftCode != nil {
                    scheduleSection
                    taskSection
                    noteSection
                }
                if viewModel.isEditing {
                    deleteSection
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { handleDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { handleSave() }
                        .disabled(!viewModel.hasUnsavedChanges)
                        .fontWeight(.semibold)
                }
            }
            .alert("Xóa ngày làm việc?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Hủy", role: .cancel) {}
                Button("Xóa", role: .destructive) { handleDelete() }
            } message: {
                Text("Hành động này không thể hoàn tác.")
            }
            .alert("Bỏ thay đổi?", isPresented: $viewModel.showDiscardConfirmation) {
                Button("Tiếp tục chỉnh sửa", role: .cancel) {}
                Button("Bỏ", role: .destructive) { dismiss() }
            } message: {
                Text("Thay đổi của bạn chưa được lưu.")
            }
            .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var dateSection: some View {
        Section {
            HStack {
                Text(WeekdayFormatter.fullName(for: viewModel.date))
                    .font(.headline)
                Spacer()
                Text(formattedDate(viewModel.date))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("\(WeekdayFormatter.fullName(for: viewModel.date)), \(formattedDate(viewModel.date))")
        }
    }

    private var shiftSection: some View {
        Section("Ca làm việc") {
            ForEach(shiftCodes, id: \.self) { code in
                Button {
                    viewModel.selectShift(code)
                } label: {
                    HStack {
                        Text(code)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(code == "OFF" ? .secondary : ShiftStyle.foregroundColor(for: code))

                        Spacer()

                        if viewModel.selectedShiftCode == code ||
                           (code == "OFF" && viewModel.selectedShiftCode == nil && viewModel.hasUnsavedChanges) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
                .accessibilityLabel("Ca \(code)")
                .accessibilityAddTraits(viewModel.selectedShiftCode == code ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        if let start = viewModel.resolvedStart,
           let end = viewModel.resolvedEnd,
           let breakStart = viewModel.resolvedBreakStart,
           let breakEnd = viewModel.resolvedBreakEnd {
            Section("Lịch làm việc") {
                LabeledContent("Thời gian") {
                    Text(TimeFormatter.formatRange(start: start, end: end))
                        .fontWeight(.medium)
                }
                LabeledContent("Nghỉ giữa ca") {
                    Text(TimeFormatter.formatRange(start: breakStart, end: breakEnd))
                }
            }
        }
    }

    @ViewBuilder
    private var taskSection: some View {
        // Structured task selection via TaskDefinition (separate from Note).
        // Task assignment NEVER modifies the shift snapshot.
        Section {
            if viewModel.availableTasks.isEmpty {
                Text("Chưa có loại công việc")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if viewModel.existingWorkDay == nil {
                Text("Lưu ca trước khi thêm công việc.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.availableTasks) { task in
                    Button {
                        viewModel.toggleTask(task)
                    } label: {
                        HStack {
                            Text(task.code)
                                .foregroundStyle(.primary)
                            Spacer()
                            if viewModel.isTaskAssigned(task) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue) // task indicator = blue
                            }
                        }
                    }
                    .accessibilityLabel("Công việc \(task.code)")
                    .accessibilityAddTraits(viewModel.isTaskAssigned(task) ? .isSelected : [])
                }
            }
        } header: {
            Text("Nhiệm vụ")
        } footer: {
            Text("Công việc là dữ liệu riêng, không ảnh hưởng giờ làm.")
        }
    }

    private var noteSection: some View {
        Section("Ghi chú") {
            TextField("Thêm ghi chú...", text: Binding(
                get: { viewModel.note },
                set: { viewModel.updateNote($0) }
            ), axis: .vertical)
            .lineLimit(3...6)
            .accessibilityLabel("Ghi chú")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Xóa ngày làm việc")
                    Spacer()
                }
            }
            .accessibilityLabel("Xóa ngày làm việc này")
        }
    }

    // MARK: - Actions

    private func handleSave() {
        if viewModel.save() {
            dismiss()
        }
    }

    private func handleDelete() {
        if viewModel.confirmDelete() {
            dismiss()
        }
    }

    private func handleDismiss() {
        if viewModel.hasUnsavedChanges {
            viewModel.showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    // MARK: - Helpers

    private var navigationTitle: String {
        viewModel.isEditing ? "Chỉnh sửa" : "Thêm ca"
    }

    private func formattedDate(_ date: Date) -> String {
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        return "\(day)/\(month)/\(year)"
    }
}
