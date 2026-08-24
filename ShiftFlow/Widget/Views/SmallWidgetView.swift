// ShiftFlow — Widget Extension
// Views/SmallWidgetView.swift
//
// TASK-WIDGET-001: Small widget view.
//
// Displays: today's shift code, start → end. OFF when no WorkDay.
// Shift code text always visible (color is supplementary only).

import SwiftUI
import ShiftFlowDomain

struct SmallWidgetView: View {
    let snapshot: WidgetScheduleSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Weekday + date header.
            if let today = snapshot.today {
                Text("\(WidgetFormatting.weekdayShort(for: today.date)) · \(WidgetFormatting.shortDate(for: today.date))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 2)

                // Shift code (always text).
                Text(today.shiftCode)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(WidgetFormatting.shiftColor(today.shiftCode))

                // Times.
                Text(WidgetFormatting.timeRange(today.startDateTime, today.endDateTime))
                    .font(.caption)
                    .foregroundStyle(.primary)

                // Task indicator.
                if today.hasTask {
                    Circle()
                        .fill(WidgetFormatting.taskColor)
                        .frame(width: 6, height: 6)
                }
            } else {
                // OFF state.
                Text(WidgetFormatting.weekdayShort(for: Date()) + " · " + WidgetFormatting.shortDate(for: Date()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 2)

                Text("OFF")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("Không có ca")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let today = snapshot.today {
            return "\(WidgetFormatting.weekdayFull(for: today.date)), ca \(today.shiftCode), \(WidgetFormatting.timeRange(today.startDateTime, today.endDateTime))"
        } else {
            return "\(WidgetFormatting.weekdayFull(for: Date())), nghỉ"
        }
    }
}
