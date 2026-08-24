// ShiftFlow — Widget Extension
// ShiftFlowWidget.swift
//
// TASK-WIDGET-001: ShiftFlow widget definition.
//
// Declares the widget, its supported families, and configuration.

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit

struct ShiftFlowWidget: Widget {
    let kind: String = "ShiftFlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShiftFlowTimelineProvider()) { entry in
            ShiftFlowWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ShiftFlow")
        .description("Xem ca làm việc hôm nay và ca sắp tới.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
#endif
