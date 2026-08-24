// ShiftFlow — Widget Extension
// Views/ShiftFlowWidgetView.swift
//
// TASK-WIDGET-001: Root widget view — dispatches to family-specific views.

import SwiftUI
import ShiftFlowDomain
#if canImport(WidgetKit)
import WidgetKit

struct ShiftFlowWidgetView: View {
    let entry: ShiftFlowEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(snapshot: entry.snapshot)
            case .systemMedium:
                MediumWidgetView(snapshot: entry.snapshot)
            case .systemLarge:
                LargeWidgetView(snapshot: entry.snapshot)
            default:
                SmallWidgetView(snapshot: entry.snapshot)
            }
        }
        // Deep link: tapping opens ShiftFlow at the relevant day.
        .widgetURL(deepLinkURL)
    }

    /// Deep link URL for the widget tap action.
    private var deepLinkURL: URL? {
        WidgetDeepLink.url(for: entry.snapshot)
    }
}
#endif
