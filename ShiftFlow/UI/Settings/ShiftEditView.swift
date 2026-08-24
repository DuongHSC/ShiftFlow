// ShiftFlow — UI Layer
// Settings/ShiftEditView.swift
//
// TASK-SETTINGS-001: Edit a single shift definition.
//
// Editable: name, start/end, break start/end, active state.
// NOT editable: code (stable identity used by WorkDay.shiftID/shiftCode).

import SwiftUI
import ShiftFlowDomain

struct ShiftEditView: View {
    @Bindable var viewModel: ShiftSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    let shift: ShiftDefinition

    // Editable local state.
    @State private var name: String
    @State private var start: Date
    @State private var end: Date
    @State private var breakStart: Date
    @State private var breakEnd: Date
    @State private var isActive: Bool

    private var calendar: Calendar { .current }

    init(viewModel: ShiftSettingsViewModel, shift: ShiftDefinition) {
        self.viewModel = viewModel
        self.shift = shift
        _name = State(initialValue: shift.name)
        _isActive = State(initialValue: shift.isActive)
        let cal = Calendar.current
        _start = State(initialValue: Self.time(cal, shift.startHour, shift.startMinute))
        _end = State(initialValue: Self.time(cal, shift.endHour, shift.endMinute))
        _breakStart = State(initialValue: Self.time(cal, shift.breakStartHour, shift.breakStartMinute))
        _breakEnd = State(initialValue: Self.time(cal, shift.breakEndHour, shift.breakEndMinute))
    }

    var body: some View {
        Form {
            Section("Mã ca") {
                // Code is read-only (stable identity).
                LabeledContent("Mã", value: shift.code)
                    .accessibilityLabel("Mã ca \(shift.code), không thể thay đổi")
            }

            Section("Tên") {
                TextField("Tên ca", text: $name)
                    .accessibilityLabel("Tên ca")
            }

            Section("Giờ làm việc") {
                DatePicker("Bắt đầu", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("Kết thúc", selection: $end, displayedComponents: .hourAndMinute)
            }

            Section("Giờ nghỉ") {
                DatePicker("Bắt đầu nghỉ", selection: $breakStart, displayedComponents: .hourAndMinute)
                DatePicker("Kết thúc nghỉ", selection: $breakEnd, displayedComponents: .hourAndMinute)
            }

            Section {
                Toggle("Đang bật", isOn: $isActive)
                    .accessibilityLabel("Bật ca \(shift.code)")
            } footer: {
                if !isActive {
                    Text("Ca này đang được sử dụng trong lịch đã lưu. Các ngày hiện tại sẽ không bị thay đổi.")
                }
            }
        }
        .navigationTitle("Ca \(shift.code)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") { save() }
            }
        }
    }

    private func save() {
        let updated = shift.withEdits(
            name: name,
            startHour: calendar.component(.hour, from: start),
            startMinute: calendar.component(.minute, from: start),
            endHour: calendar.component(.hour, from: end),
            endMinute: calendar.component(.minute, from: end),
            breakStartHour: calendar.component(.hour, from: breakStart),
            breakStartMinute: calendar.component(.minute, from: breakStart),
            breakEndHour: calendar.component(.hour, from: breakEnd),
            breakEndMinute: calendar.component(.minute, from: breakEnd),
            isActive: isActive
        )
        if viewModel.saveShift(updated) {
            dismiss()
        }
    }

    private static func time(_ cal: Calendar, _ hour: Int, _ minute: Int) -> Date {
        cal.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
}
