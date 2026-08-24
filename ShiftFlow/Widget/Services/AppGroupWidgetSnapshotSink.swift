// ShiftFlow — Widget Integration
// Services/AppGroupWidgetSnapshotSink.swift
//
// TASK-WIDGET-002: Concrete WidgetSnapshotSink for the main app.
//
// Bridges the domain's WidgetRefreshCoordinator to the platform:
// - Writes the snapshot to the App Group (WidgetDataProvider.write)
// - Requests a WidgetKit reload (WidgetDataProvider.requestReload)
//
// This is the ONLY place that connects domain widget refresh to WidgetKit.
//
// CRITICAL:
// - publish(_:) is non-throwing. Any failure is contained here and logged.
// - A widget failure must NEVER affect the WorkDay operation.

import Foundation
import ShiftFlowDomain
import os

/// App-side sink that persists the widget snapshot and requests a reload.
public final class AppGroupWidgetSnapshotSink: WidgetSnapshotSink {

    private let logger = Logger(subsystem: "com.shiftflow.app", category: "WidgetRefresh")

    public init() {}

    /// Writes the snapshot to the App Group and requests a widget reload.
    /// Non-throwing — failures are logged, never propagated.
    public func publish(_ snapshot: WidgetScheduleSnapshot) {
        // Secondary operation: contain all failures here.
        WidgetDataProvider.write(snapshot)
        WidgetDataProvider.requestReload()
        logger.debug("Widget snapshot published and reload requested.")
    }
}
