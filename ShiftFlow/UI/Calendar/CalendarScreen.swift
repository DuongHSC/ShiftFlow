// ShiftFlow — UI Layer
// Calendar/CalendarScreen.swift
//
// TASK-CALENDAR-001: Main Calendar screen.
//
// Primary screen of ShiftFlow.
// Hosts: Month, Week, 3 Days, Today views with navigation.

import SwiftUI
import ShiftFlowDomain

struct CalendarScreen: View {
    @Bindable var viewModel: CalendarViewModel
    let shiftLookup: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])?
    let workDayService: WorkDayService
    /// Optional task service for task assignment in Day Detail.
    var taskService: TaskService?

    @State private var selectedDayForDetail: Date?
    @State private var showDayDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View mode selector.
                viewModeSelector

                // Navigation header.
                navigationHeader

                // Active calendar view.
                ScrollView {
                    activeView
                }
            }
            .navigationTitle("ShiftFlow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.navigateToday()
                    } label: {
                        Text("Hôm nay")
                            .font(.caption)
                    }
                    .accessibilityLabel("Về hôm nay")
                }
            }
            .onAppear { viewModel.loadWorkDays() }
            .onChange(of: viewModel.viewMode) { _, _ in viewModel.loadWorkDays() }
            .sheet(isPresented: $showDayDetail) {
                if let date = selectedDayForDetail {
                    dayDetailSheet(for: date)
                }
            }
        }
    }

    // MARK: - View Mode Selector

    private var viewModeSelector: some View {
        Picker("Chế độ xem", selection: $viewModel.viewMode) {
            ForEach(CalendarViewMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        HStack {
            Button {
                viewModel.navigatePrevious()
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Trước")

            Spacer()

            Text(viewModel.navigationTitle())
                .font(.headline)

            Spacer()

            Button {
                viewModel.navigateNext()
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Sau")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Active View

    @ViewBuilder
    private var activeView: some View {
        switch viewModel.viewMode {
        case .month:
            MonthView(viewModel: viewModel, onDateTap: openDayDetail)
        case .week:
            WeekView(viewModel: viewModel, onDateTap: openDayDetail)
        case .threeDays:
            ThreeDaysView(viewModel: viewModel, onDateTap: openDayDetail)
        case .today:
            TodayView(viewModel: viewModel, onDateTap: openDayDetail)
        }
    }

    // MARK: - Day Detail

    private func openDayDetail(date: Date) {
        selectedDayForDetail = date
        showDayDetail = true
    }

    private func dayDetailSheet(for date: Date) -> some View {
        let existingWorkDay = viewModel.workDay(for: date)
        let detailVM = DayDetailViewModel(
            date: date,
            existingWorkDay: existingWorkDay,
            workDayService: workDayService,
            shiftLookup: shiftLookup,
            taskService: taskService
        )

        return DayDetailSheet(viewModel: detailVM)
            .onDisappear {
                // Reload data after editing.
                viewModel.loadWorkDays()
            }
    }
}
