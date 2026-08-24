// ShiftFlow — UI Layer
// Settings/ScheduleRuleEditView.swift
//
// TASK-SETTINGS-001: Edit the C5 special schedule rule (day 10–20 override).
//
// Editable: day range, start/end, break start/end, active state.
// The UI makes clear this is an override rule applied by day-of-month.

import SwiftUI
import ShiftFlowDomain

struct ScheduleRuleEditView: View {
    @Bindable var viewModel: ShiftSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    let rule: ScheduleRule

    @State private var startDay: Int
    @State private var endDay: Int
    @State private var start: Date
    @State private var end: Date
    @State private var breakStart: Date
    @State private var breakEnd: Date
    @State private var isActive: Bool

    private var calendar: Calendar { .current }

    init(viewModel: ShiftSettingsViewModel, rule: ScheduleRule) {
        self.viewModel = viewModel
        self.rule = rule
        _startDay = State(initialValue: rule.startDayOfMonth)
        _endDay = State(initialValue: rule.endDayOfMonth)
        _isActive = State(initialValue: rule.isActive)
        let cal = Calendar.current
        _start = State(initialValue: Self.time(cal, rule.startHour, rule.startMinute))
        _end = State(initialValue: Self.time(cal, rule.endHour, rule.endMinute))
        _breakStart = State(initialValue: Self.time(cal, rule.breakStartHour, rule.breakStartMinute))
        _breakEnd = State(initialValue: Self.time(cal, rule.breakEndHour, rule.breakEndMinute))
    }

    var body: some View {
        Form {
            Section {
                Text("Đây là quy tắc ghi đè lịch làm việc theo ngày trong tháng.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Khoảng ngày áp dụng") {
                Stepper("Từ ngày \(startDay)", value: $startDay, in: 1...31)
                Stepper("Đến ngày \(endDay)", value: $endDay, in: 1...31)
            }

            Section("Giờ làm theo quy tắc") {
                DatePicker("Bắt đầu", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("Kết thúc", selection: $end, displayedComponents: .hourAndMinute)
            }

            Section("Giờ nghỉ") {
                DatePicker("Bắt đầu nghỉ", selection: $breakStart, displayedComponents: .hourAndMinute)
                DatePicker("Kết thúc nghỉ", selection: $breakEnd, displayedComponents: .hourAndMinute)
            }

            Section {
                Toggle("Đang áp dụng", isOn: $isActive)
            } footer: {
                if !isActive {
                    Text("Khi tắt, C5 sẽ dùng lịch làm việc bình thường.")
                }
            }
        }
        .navigationTitle("Quy tắc C5")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") { save() }
            }
        }
    }

    private func save() {
        let updated = rule.withEdits(
            startDayOfMonth: startDay,
            endDayOfMonth: endDay,
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
        if viewModel.saveRule(updated) {
            dismiss()
        }
    }

    private static func time(_ cal: Calendar, _ hour: Int, _ minute: Int) -> Date {
        cal.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
}
