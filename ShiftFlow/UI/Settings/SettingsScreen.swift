// ShiftFlow — UI Layer
// Settings/SettingsScreen.swift
//
// TASK-SETTINGS-001: Settings screen.
//
// Sections: Shift Configuration, Schedule Rules, Reminder Defaults,
// Data Management, About. Vietnamese labels. Uses semantic colors +
// system typography (Dark Mode / Dynamic Type friendly).

import SwiftUI
import ShiftFlowDomain

struct SettingsScreen: View {
    @Bindable var viewModel: ShiftSettingsViewModel
    /// Optional task settings VM. When provided, a "Loại công việc" entry appears.
    var taskViewModel: TaskSettingsViewModel?
    /// Optional data-management VM. When provided, the "Dữ liệu" section links to
    /// the CSV import/export screens (TASK-DATA-001).
    var dataViewModel: DataManagementViewModel?

    var body: some View {
        NavigationStack {
            Form {
                shiftConfigurationSection
                scheduleRulesSection
                taskManagementSection
                reminderDefaultsSection
                dataManagementSection
                aboutSection
                resetSection
            }
            .navigationTitle("Cài đặt")
            .alert("Khôi phục ca mặc định?", isPresented: $viewModel.showResetConfirmation) {
                Button("Hủy", role: .cancel) {}
                Button("Khôi phục", role: .destructive) { viewModel.confirmReset() }
            } message: {
                Text("Thiết lập ca C1–C5 về cấu hình mặc định. Các ngày làm việc đã lưu sẽ không bị thay đổi.")
            }
            .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear { viewModel.reload() }
        }
    }

    // MARK: - Shift Configuration

    private var shiftConfigurationSection: some View {
        Section("Ca làm việc") {
            ForEach(viewModel.shifts) { shift in
                NavigationLink {
                    ShiftEditView(viewModel: viewModel, shift: shift)
                } label: {
                    shiftRow(shift)
                }
                .accessibilityLabel(shiftAccessibilityLabel(shift))
            }
        }
    }

    private func shiftRow(_ shift: ShiftDefinition) -> some View {
        HStack {
            Text(shift.code)
                .font(.headline)
                .foregroundStyle(ShiftStyle.foregroundColor(for: shift.code))
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeRange(shift.startHour, shift.startMinute, shift.endHour, shift.endMinute))
                    .font(.subheadline)
                Text("Nghỉ \(timeRange(shift.breakStartHour, shift.breakStartMinute, shift.breakEndHour, shift.breakEndMinute))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !shift.isActive {
                Text("Đã tắt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5), in: Capsule())
            }
        }
    }

    // MARK: - Schedule Rules

    @ViewBuilder
    private var scheduleRulesSection: some View {
        Section {
            if let rule = viewModel.c5Rule {
                NavigationLink {
                    ScheduleRuleEditView(viewModel: viewModel, rule: rule)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("C5 — Quy tắc ngày \(rule.startDayOfMonth)–\(rule.endDayOfMonth)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Giờ làm theo quy tắc: \(timeRange(rule.startHour, rule.startMinute, rule.endHour, rule.endMinute))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(rule.isActive ? "Đang áp dụng" : "Đã tắt")
                            .font(.caption2)
                            .foregroundStyle(rule.isActive ? .green : .secondary)
                    }
                }
            }
        } header: {
            Text("Quy tắc lịch")
        } footer: {
            Text("Quy tắc áp dụng theo ngày trong tháng.")
        }
    }

    // MARK: - Task Management

    @ViewBuilder
    private var taskManagementSection: some View {
        if let taskViewModel = taskViewModel {
            Section {
                NavigationLink {
                    TaskSettingsView(viewModel: taskViewModel)
                } label: {
                    Label("Loại công việc", systemImage: "checklist")
                }
                .accessibilityLabel("Quản lý loại công việc")
            }
        }
    }

    // MARK: - Reminder Defaults

    private var reminderDefaultsSection: some View {
        Section("Nhắc ca") {
            Picker("Mặc định", selection: $viewModel.defaultReminderOffset) {
                ForEach(ReminderOffset.allCases) { offset in
                    Text(offset.displayName).tag(offset)
                }
            }
            .accessibilityLabel("Nhắc ca mặc định")
        }
    }

    // MARK: - Data Management

    @ViewBuilder
    private var dataManagementSection: some View {
        if let dataViewModel = dataViewModel {
            Section {
                NavigationLink {
                    DataManagementView(viewModel: dataViewModel)
                } label: {
                    Label("Dữ liệu", systemImage: "externaldrive")
                }
                .accessibilityLabel("Quản lý dữ liệu: nhập và xuất CSV")
            } header: {
                Text("Dữ liệu")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("Giới thiệu") {
            LabeledContent("Phiên bản", value: "0.9.1")
            LabeledContent("Sản phẩm", value: "ShiftFlow")
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showResetConfirmation = true
            } label: {
                Text("Khôi phục ca mặc định")
            }
            .accessibilityLabel("Khôi phục ca mặc định về cấu hình gốc")
        }
    }

    // MARK: - Helpers

    private func timeRange(_ sh: Int, _ sm: Int, _ eh: Int, _ em: Int) -> String {
        String(format: "%02d:%02d → %02d:%02d", sh, sm, eh, em)
    }

    private func shiftAccessibilityLabel(_ shift: ShiftDefinition) -> String {
        let times = "từ \(shift.startHour) giờ \(shift.startMinute) đến \(shift.endHour) giờ \(shift.endMinute)"
        let brk = "nghỉ từ \(shift.breakStartHour) giờ \(shift.breakStartMinute) đến \(shift.breakEndHour) giờ \(shift.breakEndMinute)"
        let state = shift.isActive ? "đang bật" : "đã tắt"
        return "Ca \(shift.code), \(times), \(brk), \(state)"
    }
}
