// ShiftFlow — UI Layer
// Calendar/MonthView.swift
//
// TASK-CALENDAR-001: Month calendar view.
//
// Displays a standard 7-column calendar grid (Monday-first).
// Each cell shows: date, shift code, task indicator, note indicator.
// Shift code is ALWAYS textual — color is supplementary only.

import SwiftUI
import ShiftFlowDomain

struct MonthView: View {
    let viewModel: CalendarViewModel
    let onDateTap: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 4) {
            // Weekday header row.
            HStack(spacing: 0) {
                ForEach(WeekdayFormatter.mondayFirstShortNames, id: \.self) { name in
                    Text(name)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Calendar grid.
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(viewModel.monthGridDates(), id: \.self) { date in
                    MonthDayCell(
                        date: date,
                        workDay: viewModel.workDay(for: date),
                        isCurrentMonth: viewModel.isInCurrentMonth(date),
                        isToday: viewModel.isToday(date),
                        calendar: .current
                    )
                    .onTapGesture { onDateTap(date) }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel(for: date))
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func accessibilityLabel(for date: Date) -> String {
        let weekday = WeekdayFormatter.fullName(for: date)
        let day = Calendar.current.component(.day, from: date)
        let month = Calendar.current.component(.month, from: date)

        var label = "\(weekday), ngày \(day) tháng \(month)"

        if let wd = viewModel.workDay(for: date) {
            label += ", \(wd.shiftCode)"
            label += ", \(TimeFormatter.formatRange(start: wd.resolvedStartDateTime, end: wd.resolvedEndDateTime))"
        } else {
            label += ", OFF"
        }

        return label
    }
}

// MARK: - Day Cell

private struct MonthDayCell: View {
    let date: Date
    let workDay: WorkDay?
    let isCurrentMonth: Bool
    let isToday: Bool
    let calendar: Calendar

    var body: some View {
        VStack(spacing: 1) {
            // Date number.
            Text("\(calendar.component(.day, from: date))")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isCurrentMonth ? .primary : .tertiary)

            // Shift code (always text, never color-only).
            if let wd = workDay {
                Text(wd.shiftCode)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(ShiftStyle.foregroundColor(for: wd.shiftCode))

                // Task indicator (blue dot — tasks only).
                // Note indicator.
                HStack(spacing: 2) {
                    if wd.note != nil && !(wd.note?.isEmpty ?? true) {
                        Text("📝")
                            .font(.system(size: 6))
                    }
                }
            } else if isCurrentMonth {
                Text("OFF")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(cellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    private var cellBackground: Color {
        if let wd = workDay {
            return ShiftStyle.backgroundColor(for: wd.shiftCode)
        }
        return Color.clear
    }
}
