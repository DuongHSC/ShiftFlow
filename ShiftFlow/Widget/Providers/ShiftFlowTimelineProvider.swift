// ShiftFlow — Widget Extension
// Providers/ShiftFlowTimelineProvider.swift
//
// TASK-WIDGET-001: WidgetKit timeline provider.
//
// Provides timeline entries built from the shared WidgetScheduleSnapshot.
// Does NOT calculate shift times — reads pre-built snapshot from App Group.

import Foundation
import ShiftFlowDomain
#if canImport(WidgetKit)
import WidgetKit

/// A single timeline entry for the ShiftFlow widget.
struct ShiftFlowEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetScheduleSnapshot
}

/// Timeline provider for the ShiftFlow widget.
///
/// Reads the widget snapshot from the App Group and produces timeline entries.
/// Refresh policy: refresh at the next day boundary (midnight) so "today" updates.
struct ShiftFlowTimelineProvider: TimelineProvider {

    private var calendar: Calendar { .current }

    /// Placeholder shown while the widget loads.
    func placeholder(in context: Context) -> ShiftFlowEntry {
        ShiftFlowEntry(date: Date(), snapshot: .empty)
    }

    /// Snapshot for the widget gallery/preview.
    func getSnapshot(in context: Context, completion: @escaping (ShiftFlowEntry) -> Void) {
        let snapshot = WidgetDataProvider.read()
        completion(ShiftFlowEntry(date: Date(), snapshot: snapshot))
    }

    /// Builds the timeline with a refresh at the next midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShiftFlowEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetDataProvider.read()

        let entry = ShiftFlowEntry(date: now, snapshot: snapshot)

        // Refresh at the next day boundary so "today" advances correctly.
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? calendar.date(byAdding: .day, value: 1, to: now)!

        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}
#endif
