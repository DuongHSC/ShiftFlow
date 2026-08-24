// ShiftFlow — Application Layer
// ViewModels/CalendarViewModel.swift
//
// TASK-CALENDAR-001: Calendar ViewModel.
//
// Manages calendar state, date navigation, WorkDay loading, and view switching.
// Does NOT contain shift-resolution logic — delegates to WorkDayService/ShiftResolver.
//
// Architecture: UI → ViewModel → WorkDayService → ShiftResolver

import Foundation
import SwiftUI
import ShiftFlowDomain

/// The four calendar presentation modes.
public enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month = "Tháng"
    case week = "Tuần"
    case threeDays = "3 Ngày"
    case today = "Hôm nay"

    public var id: String { rawValue }
}

/// Main ViewModel for the Calendar screen.
///
/// Manages:
/// - Current selected date and navigation
/// - Active view mode (Month/Week/3Days/Today)
/// - WorkDay data for the visible range
/// - Next shift query for Today view
@Observable
public final class CalendarViewModel {

    // MARK: - Published State

    public var viewMode: CalendarViewMode = .month
    public var selectedDate: Date
    public var workDays: [Date: WorkDay] = [:]
    public var nextShift: WorkDay?
    public var isLoading: Bool = false
    public var errorMessage: String?

    // MARK: - Dependencies

    private let workDayService: WorkDayService
    private let calendar: Calendar

    // MARK: - Initialization

    public init(workDayService: WorkDayService, calendar: Calendar = .current) {
        self.workDayService = workDayService
        self.calendar = calendar
        self.selectedDate = calendar.startOfDay(for: Date())
    }

    // MARK: - Navigation

    /// Navigate to the previous period based on current view mode.
    public func navigatePrevious() {
        switch viewMode {
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .threeDays:
            selectedDate = calendar.date(byAdding: .day, value: -3, to: selectedDate) ?? selectedDate
        case .today:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
        loadWorkDays()
    }

    /// Navigate to the next period based on current view mode.
    public func navigateNext() {
        switch viewMode {
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .threeDays:
            selectedDate = calendar.date(byAdding: .day, value: 3, to: selectedDate) ?? selectedDate
        case .today:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        }
        loadWorkDays()
    }

    /// Navigate to today.
    public func navigateToday() {
        selectedDate = calendar.startOfDay(for: Date())
        loadWorkDays()
    }

    // MARK: - Data Loading

    /// Loads WorkDays for the currently visible date range.
    public func loadWorkDays() {
        isLoading = true
        errorMessage = nil

        let (start, end) = visibleDateRange()

        do {
            let loaded = try workDayService.fetchWorkDays(from: start, to: end)
            var map: [Date: WorkDay] = [:]
            for wd in loaded {
                let key = calendar.startOfDay(for: wd.date)
                map[key] = wd
            }
            workDays = map

            // Load next shift for Today view.
            if viewMode == .today {
                loadNextShift()
            }
        } catch {
            errorMessage = "Không thể tải lịch làm việc."
            workDays = [:]
        }

        isLoading = false
    }

    /// Loads the next scheduled WorkDay after today.
    public func loadNextShift() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let futureEnd = calendar.date(byAdding: .day, value: 90, to: tomorrow)!

        do {
            let future = try workDayService.fetchWorkDays(from: tomorrow, to: futureEnd)
            nextShift = future.first
        } catch {
            nextShift = nil
        }
    }

    // MARK: - WorkDay Access

    /// Returns the WorkDay for a specific date, if one exists.
    public func workDay(for date: Date) -> WorkDay? {
        let key = calendar.startOfDay(for: date)
        return workDays[key]
    }

    // MARK: - Date Range Calculation

    /// Returns the visible date range for the current view mode and selected date.
    public func visibleDateRange() -> (start: Date, end: Date) {
        switch viewMode {
        case .month:
            return monthRange(for: selectedDate)
        case .week:
            return weekRange(for: selectedDate)
        case .threeDays:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 2, to: start)!
            return (start, end)
        case .today:
            let today = calendar.startOfDay(for: selectedDate)
            return (today, today)
        }
    }

    /// Returns the dates for the month grid (includes leading/trailing days).
    public func monthGridDates() -> [Date] {
        let range = monthRange(for: selectedDate)
        let firstOfMonth = range.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)

        // Adjust for Monday-first (weekday 2 = Monday in Gregorian).
        let mondayOffset = (weekdayOfFirst + 5) % 7 // days before Monday

        let gridStart = calendar.date(byAdding: .day, value: -mondayOffset, to: firstOfMonth)!

        var dates: [Date] = []
        for i in 0..<42 { // 6 weeks × 7 days
            if let date = calendar.date(byAdding: .day, value: i, to: gridStart) {
                dates.append(date)
            }
        }
        return dates
    }

    /// Returns dates for the current week (Monday to Sunday).
    public func weekDates() -> [Date] {
        let weekStart = startOfWeek(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// Returns dates for the 3-day view.
    public func threeDayDates() -> [Date] {
        let start = calendar.startOfDay(for: selectedDate)
        return (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    // MARK: - Display Title

    /// Returns the navigation title for the current view mode.
    public func navigationTitle() -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "vi_VN")

        switch viewMode {
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate).capitalized
        case .week:
            let dates = weekDates()
            guard let first = dates.first, let last = dates.last else { return "" }
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "dd/MM"
            dayFmt.calendar = calendar
            return "\(dayFmt.string(from: first)) – \(dayFmt.string(from: last))"
        case .threeDays:
            let dates = threeDayDates()
            guard let first = dates.first, let last = dates.last else { return "" }
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "dd/MM"
            dayFmt.calendar = calendar
            return "\(dayFmt.string(from: first)) – \(dayFmt.string(from: last))"
        case .today:
            formatter.dateFormat = "EEEE, dd MMMM yyyy"
            return formatter.string(from: selectedDate).capitalized
        }
    }

    // MARK: - Helpers

    /// Whether a date is in the currently displayed month.
    public func isInCurrentMonth(_ date: Date) -> Bool {
        calendar.component(.month, from: date) == calendar.component(.month, from: selectedDate) &&
        calendar.component(.year, from: date) == calendar.component(.year, from: selectedDate)
    }

    /// Whether a date is today.
    public func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    // MARK: - Private Helpers

    private func monthRange(for date: Date) -> (start: Date, end: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstOfMonth = calendar.date(from: components)!
        let lastOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth)!
        return (firstOfMonth, lastOfMonth)
    }

    private func weekRange(for date: Date) -> (start: Date, end: Date) {
        let weekStart = startOfWeek(for: date)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        return (weekStart, weekEnd)
    }

    private func startOfWeek(for date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: date))!
    }
}
