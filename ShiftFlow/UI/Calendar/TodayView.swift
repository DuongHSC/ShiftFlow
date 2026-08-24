// ShiftFlow — UI Layer
// Calendar/TodayView.swift
//
// TASK-CALENDAR-001: Today view.
//
// Displays today's full schedule detail and next scheduled shift.
// Uses WorkDay snapshot for resolved times — no independent calculation.

import SwiftUI
import ShiftFlowDomain

struct TodayView: View {
    let viewModel: CalendarViewModel
    let onDateTap: (Date) -> Void

    private var calendar: Calendar { .current }
    private var todayWorkDay: WorkDay? { viewModel.workDay(for: viewModel.selectedDate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                todaySection
                nextShiftSection
            }
            .padding()
        }
    }

    // MARK: - Today Section

    @ViewBuilder
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Weekday + full date.
            Text(WeekdayFormatter.fullName(for: viewModel.selectedDate).uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Text(formattedDate(viewModel.selectedDate))
                .font(.title2)
                .fontWeight(.bold)

            if let wd = todayWorkDay {
                // Shift card.
                VStack(alignment: .leading, spacing: 12) {
                    // Shift code.
                    Text(wd.shiftCode)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(ShiftStyle.foregroundColor(for: wd.shiftCode))

                    // Working time.
                    LabeledContent("Thời gian") {
                        Text(TimeFormatter.formatRange(
                            start: wd.resolvedStartDateTime,
                            end: wd.resolvedEndDateTime
                        ))
                        .fontWeight(.medium)
                    }

                    // Break.
                    LabeledContent("Nghỉ giữa ca") {
                        Text(TimeFormatter.formatRange(
                            start: wd.resolvedBreakStartDateTime,
                            end: wd.resolvedBreakEndDateTime
                        ))
                    }

                    Divider()

                    // Task.
                    LabeledContent("Nhiệm vụ") {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }

                    // Note.
                    if let note = wd.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ghi chú")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(note)
                                .font(.body)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ShiftStyle.backgroundColor(for: wd.shiftCode))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
                )
                .onTapGesture { onDateTap(viewModel.selectedDate) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(todayAccessibilityLabel(wd))
            } else {
                // OFF state.
                VStack(spacing: 8) {
                    Text("OFF")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("Không có ca làm việc")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .onTapGesture { onDateTap(viewModel.selectedDate) }
            }
        }
    }

    // MARK: - Next Shift Section

    @ViewBuilder
    private var nextShiftSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CA TIẾP THEO")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            if let next = viewModel.nextShift {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(WeekdayFormatter.fullName(for: next.date)) · \(formattedShortDate(next.date))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Text(next.shiftCode)
                                .font(.headline)
                                .foregroundStyle(ShiftStyle.foregroundColor(for: next.shiftCode))

                            Text(TimeFormatter.formatRange(
                                start: next.resolvedStartDateTime,
                                end: next.resolvedEndDateTime
                            ))
                            .font(.subheadline)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                .accessibilityLabel("Ca tiếp theo: \(WeekdayFormatter.fullName(for: next.date)), \(next.shiftCode), \(TimeFormatter.formatRange(start: next.resolvedStartDateTime, end: next.resolvedEndDateTime))")
            } else {
                Text("Không có ca làm việc sắp tới")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        return "Ngày \(day) tháng \(month), \(year)"
    }

    private func formattedShortDate(_ date: Date) -> String {
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        return "\(day)/\(month)"
    }

    private func todayAccessibilityLabel(_ wd: WorkDay) -> String {
        var label = "\(wd.shiftCode), \(TimeFormatter.formatRange(start: wd.resolvedStartDateTime, end: wd.resolvedEndDateTime))"
        label += ", nghỉ \(TimeFormatter.formatRange(start: wd.resolvedBreakStartDateTime, end: wd.resolvedBreakEndDateTime))"
        if let note = wd.note, !note.isEmpty {
            label += ", ghi chú: \(note)"
        }
        return label
    }
}
