// ShiftFlow — Widget Extension
// Views/MediumWidgetView.swift
//
// TASK-WIDGET-001: Medium widget view.
//
// Displays: Today (shift, start→end, break, task indicator) + Next Shift summary.
// Shift code text always visible.

import SwiftUI
import ShiftFlowDomain

struct MediumWidgetView: View {
    let snapshot: WidgetScheduleSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            todayColumn
            Divider()
            nextColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Today Column

    @ViewBuilder
    private var todayColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HÔM NAY")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            if let today = snapshot.today {
                Text("\(WidgetFormatting.weekdayShort(for: today.date)) · \(WidgetFormatting.shortDate(for: today.date))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(today.shiftCode)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(WidgetFormatting.shiftColor(today.shiftCode))

                    if today.hasTask {
                        Circle()
                            .fill(WidgetFormatting.taskColor)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(WidgetFormatting.timeRange(today.startDateTime, today.endDateTime))
                    .font(.caption)

                Text("Nghỉ \(WidgetFormatting.timeRange(today.breakStartDateTime, today.breakEndDateTime))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("OFF")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Next Shift Column

    @ViewBuilder
    private var nextColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CA TIẾP THEO")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            if let next = snapshot.nextShift {
                Text("\(WidgetFormatting.weekdayShort(for: next.date)) · \(WidgetFormatting.shortDate(for: next.date))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(next.shiftCode)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(WidgetFormatting.shiftColor(next.shiftCode))

                Text(WidgetFormatting.timeRange(next.startDateTime, next.endDateTime))
                    .font(.caption)
            } else {
                Text("Không có ca sắp tới")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let today = snapshot.today {
            parts.append("Hôm nay \(WidgetFormatting.weekdayFull(for: today.date)), ca \(today.shiftCode), \(WidgetFormatting.timeRange(today.startDateTime, today.endDateTime)), nghỉ \(WidgetFormatting.timeRange(today.breakStartDateTime, today.breakEndDateTime))")
        } else {
            parts.append("Hôm nay nghỉ")
        }
        if let next = snapshot.nextShift {
            parts.append("Ca tiếp theo \(WidgetFormatting.weekdayFull(for: next.date)), ca \(next.shiftCode), \(WidgetFormatting.timeRange(next.startDateTime, next.endDateTime))")
        } else {
            parts.append("Không có ca làm việc sắp tới")
        }
        return parts.joined(separator: ". ")
    }
}
