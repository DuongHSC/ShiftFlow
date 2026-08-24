// ShiftFlow — UI Layer
// Calendar/ThreeDaysView.swift
//
// TASK-CALENDAR-001: 3 Days calendar view.
//
// Displays three consecutive days with full detail:
// weekday, date, shift, start/end, break, task, note.

import SwiftUI
import ShiftFlowDomain

struct ThreeDaysView: View {
    let viewModel: CalendarViewModel
    let onDateTap: (Date) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.threeDayDates(), id: \.self) { date in
                ThreeDayCard(
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
        let month = Calendar.current.component(.month, from: date)

        var label = "\(weekday), ngày \(day) tháng \(month)"

        if let wd = viewModel.workDay(for: date) {
            label += ", \(wd.shiftCode)"
            label += ", \(TimeFormatter.formatRange(start: wd.resolvedStartDateTime, end: wd.resolvedEndDateTime))"
            label += ", nghỉ \(TimeFormatter.formatRange(start: wd.resolvedBreakStartDateTime, end: wd.resolvedBreakEndDateTime))"
            if let note = wd.note, !note.isEmpty {
                label += ", ghi chú: \(note)"
            }
        } else {
            label += ", OFF"
        }

        return label
    }
}

private struct ThreeDayCard: View {
    let date: Date
    let workDay: WorkDay?
    let isToday: Bool

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: weekday + date.
            HStack {
                Text(WeekdayFormatter.fullName(for: date))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("· \(calendar.component(.day, from: date))/\(calendar.component(.month, from: date))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isToday {
                    Text("HÔM NAY")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }

                Spacer()
            }

            if let wd = workDay {
                HStack(alignment: .top, spacing: 16) {
                    // Shift code.
                    Text(wd.shiftCode)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(ShiftStyle.foregroundColor(for: wd.shiftCode))

                    VStack(alignment: .leading, spacing: 4) {
                        // Working time.
                        Text(TimeFormatter.formatRange(
                            start: wd.resolvedStartDateTime,
                            end: wd.resolvedEndDateTime
                        ))
                        .font(.subheadline)

                        // Break.
                        Text("Nghỉ: \(TimeFormatter.formatRange(start: wd.resolvedBreakStartDateTime, end: wd.resolvedBreakEndDateTime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Note.
                        if let note = wd.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }
            } else {
                Text("OFF")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isToday ? Color.accentColor.opacity(0.4) : Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private var cardBackground: Color {
        if let wd = workDay {
            return ShiftStyle.backgroundColor(for: wd.shiftCode)
        }
        return Color(.systemBackground)
    }
}
