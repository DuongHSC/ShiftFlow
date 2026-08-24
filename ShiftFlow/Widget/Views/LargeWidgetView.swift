// ShiftFlow — Widget Extension
// Views/LargeWidgetView.swift
//
// TASK-WIDGET-001: Large widget view.
//
// Displays: Today schedule, Next Shift, upcoming days with task indicators.
// Note text is NOT exposed (only indicators). Shift code always visible.

import SwiftUI
import ShiftFlowDomain

struct LargeWidgetView: View {
    let snapshot: WidgetScheduleSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header.
            Text("SHIFTFLOW")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            // Today.
            todaySection

            Divider()

            // Upcoming schedule.
            upcomingSection

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Today

    @ViewBuilder
    private var todaySection: some View {
        if let today = snapshot.today {
            HStack(spacing: 10) {
                Text(today.shiftCode)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(WidgetFormatting.shiftColor(today.shiftCode))
                    .frame(width: 44, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HÔM NAY · \(WidgetFormatting.weekdayFull(for: today.date))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(WidgetFormatting.timeRange(today.startDateTime, today.endDateTime))
                        .font(.subheadline)
                    Text("Nghỉ \(WidgetFormatting.timeRange(today.breakStartDateTime, today.breakEndDateTime))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if today.hasTask {
                    Circle().fill(WidgetFormatting.taskColor).frame(width: 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hôm nay \(WidgetFormatting.weekdayFull(for: today.date)), ca \(today.shiftCode), \(WidgetFormatting.timeRange(today.startDateTime, today.endDateTime))")
        } else {
            HStack {
                Text("HÔM NAY")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("OFF")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Hôm nay nghỉ")
        }
    }

    // MARK: - Upcoming

    @ViewBuilder
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LỊCH SẮP TỚI")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            // Show upcoming days after today (exclude today itself).
            let upcomingAfterToday = snapshot.upcoming.filter { entry in
                if let today = snapshot.today {
                    return entry.date != today.date
                }
                return true
            }

            if upcomingAfterToday.isEmpty {
                Text("Không có ca làm việc sắp tới")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(upcomingAfterToday.prefix(4), id: \.date) { entry in
                    HStack(spacing: 8) {
                        Text(WidgetFormatting.weekdayShort(for: entry.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)

                        Text(entry.shiftCode)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(WidgetFormatting.shiftColor(entry.shiftCode))
                            .frame(width: 28, alignment: .leading)

                        Text(WidgetFormatting.timeRange(entry.startDateTime, entry.endDateTime))
                            .font(.caption)

                        Spacer()

                        if entry.hasTask {
                            Circle().fill(WidgetFormatting.taskColor).frame(width: 6, height: 6)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(WidgetFormatting.weekdayFull(for: entry.date)), ca \(entry.shiftCode), \(WidgetFormatting.timeRange(entry.startDateTime, entry.endDateTime))")
                }
            }
        }
    }
}
