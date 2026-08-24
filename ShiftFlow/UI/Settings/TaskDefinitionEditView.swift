// ShiftFlow — UI Layer
// Settings/TaskDefinitionEditView.swift
//
// TASK-TASK-002: Edit a task definition.
//
// Editable: name, active state. Code is READ-ONLY (stable identity used by
// existing WorkDayTask references).

import SwiftUI
import ShiftFlowDomain

struct TaskDefinitionEditView: View {
    @Bindable var viewModel: TaskSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    let task: TaskDefinition

    @State private var name: String
    @State private var isActive: Bool

    init(viewModel: TaskSettingsViewModel, task: TaskDefinition) {
        self.viewModel = viewModel
        self.task = task
        _name = State(initialValue: task.name)
        _isActive = State(initialValue: task.isActive)
    }

    var body: some View {
        Form {
            Section("Mã công việc") {
                // Code is read-only (stable identity).
                LabeledContent("Mã", value: task.code)
                    .accessibilityLabel("Mã công việc \(task.code), không thể thay đổi")
            }

            Section("Tên") {
                TextField("Tên công việc", text: $name)
                    .accessibilityLabel("Tên công việc")
            }

            Section {
                Toggle("Đang bật", isOn: $isActive)
                    .accessibilityLabel("Bật công việc \(task.code)")
            } footer: {
                if !isActive {
                    Text("Công việc đã tắt không thể gán mới. Các ngày đã lưu vẫn giữ nguyên.")
                }
            }
        }
        .navigationTitle(task.code)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") {
                    if viewModel.updateTask(task, name: name, isActive: isActive) {
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
