// ShiftFlow — UI Layer
// Settings/TaskSettingsView.swift
//
// TASK-TASK-002: Task management screen ("Loại công việc").
//
// Lists TaskDefinitions, allows add/edit/enable/disable/delete via TaskService.
// Uses semantic colors + system typography (Dark Mode / Dynamic Type friendly).
// Shift/task independence: this screen never calls ShiftResolver.

import SwiftUI
import ShiftFlowDomain

struct TaskSettingsView: View {
    @Bindable var viewModel: TaskSettingsViewModel

    @State private var showAddSheet = false
    @State private var taskPendingDelete: TaskDefinition?
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                ForEach(viewModel.tasks) { task in
                    NavigationLink {
                        TaskDefinitionEditView(viewModel: viewModel, task: task)
                    } label: {
                        taskRow(task)
                    }
                    .accessibilityLabel(viewModel.accessibilityLabel(for: task))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            taskPendingDelete = task
                            showDeleteConfirmation = true
                        } label: {
                            Label("Xóa", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("Công việc là dữ liệu riêng, không ảnh hưởng giờ làm.")
            }
        }
        .navigationTitle("Loại công việc")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Thêm công việc", systemImage: "plus")
                }
                .accessibilityLabel("Thêm công việc")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            TaskDefinitionAddView(viewModel: viewModel)
        }
        .alert("Xóa công việc?", isPresented: $showDeleteConfirmation) {
            Button("Hủy", role: .cancel) { taskPendingDelete = nil }
            Button("Xóa", role: .destructive) {
                if let task = taskPendingDelete { _ = viewModel.deleteTask(task) }
                taskPendingDelete = nil
            }
        } message: {
            Text("Hành động này không thể hoàn tác.")
        }
        .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear { viewModel.reload() }
    }

    // MARK: - Row

    private func taskRow(_ task: TaskDefinition) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.code)
                    .font(.headline)
                Text(task.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // State shown as text (never color-only).
            Text(task.isActive ? "Đang bật" : "Đã tắt")
                .font(.caption2)
                .foregroundStyle(task.isActive ? .primary : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray6), in: Capsule())
        }
    }
}

// MARK: - Add Task Sheet

struct TaskDefinitionAddView: View {
    @Bindable var viewModel: TaskSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Mã công việc") {
                    TextField("Mã (VD: Ticket)", text: $code)
                        .accessibilityLabel("Mã công việc")
                }
                Section("Tên") {
                    TextField("Tên công việc", text: $name)
                        .accessibilityLabel("Tên công việc")
                }
            }
            .navigationTitle("Thêm công việc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        if viewModel.createTask(code: code, name: name) {
                            dismiss()
                        }
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty
                              || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
