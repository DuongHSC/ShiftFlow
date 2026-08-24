// ShiftFlow — UI Layer
// Shared/ShiftStyle.swift
//
// TASK-CALENDAR-001: Shift visual styling.
//
// Provides supplementary colors for shifts.
// Color is NEVER the only identifier — shift code text is always displayed.
//
// Blue is reserved for task indicators only.
// Blue is NOT a shift color.

import SwiftUI

/// Visual styling for shift codes.
///
/// Color is supplementary only. The shift code text (C1, C2, C3, C4, C5)
/// must ALWAYS be displayed alongside any color.
public enum ShiftStyle {

    /// Background color for a shift code.
    public static func backgroundColor(for code: String) -> Color {
        switch code.uppercased() {
        case "C5": return Color.red.opacity(0.15)
        case "C4": return Color(.systemGray6)
        case "C3": return Color.green.opacity(0.15)
        case "C2": return Color.orange.opacity(0.1)
        case "C1": return Color.purple.opacity(0.1)
        default: return Color.clear
        }
    }

    /// Foreground/accent color for a shift code.
    public static func foregroundColor(for code: String) -> Color {
        switch code.uppercased() {
        case "C5": return Color.red
        case "C4": return Color(.label)
        case "C3": return Color.green
        case "C2": return Color.orange
        case "C1": return Color.purple
        default: return Color(.secondaryLabel)
        }
    }

    /// Task indicator color (blue — tasks only, never shifts).
    public static let taskIndicatorColor: Color = .blue
}
