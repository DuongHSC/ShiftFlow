// ShiftFlow — Widget Extension
// Services/WidgetDataProvider.swift
//
// TASK-WIDGET-001: Widget data provider (App Group shared storage).
//
// Reads/writes the WidgetScheduleSnapshot from/to the shared App Group container.
// The main app writes the snapshot; the Widget reads it.
//
// ARCHITECTURE:
// Main App → WidgetScheduleBuilder → WidgetScheduleSnapshot → App Group → Widget
//
// The Widget NEVER computes shift times. It reads a pre-built snapshot.

import Foundation
import ShiftFlowDomain
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Provides widget schedule data via the shared App Group container.
public enum WidgetDataProvider {

    /// Planned App Group identifier.
    /// Actual Xcode capability configuration must be completed on macOS.
    public static let appGroupIdentifier = "group.com.shiftflow.shared"

    /// Key under which the snapshot is stored in the shared UserDefaults.
    public static let snapshotKey = "shiftflow.widget.snapshot"

    // MARK: - Write (Main App)

    /// Writes a widget snapshot to the shared App Group container.
    /// Called by the main app when schedule data changes.
    ///
    /// - Parameter snapshot: The snapshot to persist for the widget.
    public static func write(_ snapshot: WidgetScheduleSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: snapshotKey)
        } catch {
            // Encoding failure — leave previous snapshot intact.
        }
    }

    /// Requests a WidgetKit timeline reload after data changes.
    public static func requestReload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Read (Widget)

    /// Reads the current widget snapshot from the shared App Group container.
    ///
    /// - Returns: The stored snapshot, or `.empty` if none/unreadable.
    public static func read() -> WidgetScheduleSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: snapshotKey) else {
            return .empty
        }
        do {
            return try JSONDecoder().decode(WidgetScheduleSnapshot.self, from: data)
        } catch {
            return .empty
        }
    }
}
