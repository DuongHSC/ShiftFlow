// ShiftFlow — Widget Extension
// ShiftFlowWidgetBundle.swift
//
// TASK-WIDGET-001: Widget bundle entry point.

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit

@main
struct ShiftFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShiftFlowWidget()
    }
}
#endif
