// ShiftFlow — UI Layer
// Calendar/WeekView.swift
//
// TASK-CALENDAR-001: Week calendar view.
//
// Displays 7 days (Monday–Sunday) with shift, resolved times, and indicators.
// Shift code is always textual.

import SwiftUI
import ShiftFlowDomain

struct WeekView: View {
    let viewModel: CalendarViewModel
    let onDateTap: (Date) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.weekDates(), id: \.self) { date in
                WeekDayRow(
                    date: date,
                    workDay: viewModel.workDay(for: date),
                    isToday: viewModel.isToday(date)
                )
                .onTapGesture { onDateTap(date) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(for: date))
            }
        }
        .padding(.horizontal)
    }

    private func accessibilityLabel(for date: Date) -> String {
        let weekday = WeekdayFormatter.fullName(for: date)
        let day = Calendar.current.component(.day, from: date)

        var label = "\(weekday), ngày \(day)"

        if let wd = viewModel.workDay(for: date) {
            label += ", \(wd.shiftCode)"
            label += ", \(TimeFormatter.formatRange(start: wd.resolvedStartDateTime, end: wd.resolvedEndDateTime))"
        } else {
            label += ", OFF"
        }

        return label
    }
}

private struct WeekDayRow: View {
    let date: Date
    let workDay: WorkDay?
    let isToday: Bool

    private var calendar: Calendar { .current }

    var body: some View {
        HStack(spacing: 12) {
            // Weekday + date.
            VStack(alignment: .leading, spacing: 2) {
                Text(WeekdayFormatter.shortName(for: date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(calendar.component(.day, from: date))")
                    .font(.title3)
                    .fontWeight(isToday ? .bold : .regular)
            }
            .frame(width: 36, alignment: .leading)

            if let wd = workDay {
                // Shift code (always text).
                Text(wd.shiftCode)
                    .font(.headline)
                    .foregroundStyle(ShiftStyle.foregroundColor(for: wd.shiftCode))
                    .frame(width: 30)

                // Resolved times.
                Text(TimeFormatter.formatRange(
                    start: wd.resolvedStartDateTime,
                    end: wd.resolvedEndDateTime
                ))
                .font(.subheadline)
                .foregroundStyle(.primary)

                Spacer()

                // Task indicator (blue).
                // Note indicator.
                if wd.note != nil && !(wd.note?.isEmpty ?? true) {
                    Text("📝")
                        .font(.caption)
                }
            } else {
                Text("OFF")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.accentColor.opacity(0.08) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.accentColor.opacity(0.3) : Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
    }
}
