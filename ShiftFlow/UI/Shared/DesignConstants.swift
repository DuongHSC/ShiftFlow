// ShiftFlow — UI Layer
// Shared/DesignConstants.swift
//
// TASK-POLISH-001: Centralized spacing and layout constants.
//
// Provides a consistent spacing/sizing system so views avoid arbitrary
// one-off values. Uses a simple 4pt-based scale aligned with iOS conventions.

import SwiftUI

/// Consistent design constants for ShiftFlow UI.
enum DesignConstants {

    // MARK: - Spacing (4pt scale)

    enum Spacing {
        /// 4pt — tight inner spacing.
        static let xs: CGFloat = 4
        /// 8pt — compact spacing.
        static let sm: CGFloat = 8
        /// 12pt — default element spacing.
        static let md: CGFloat = 12
        /// 16pt — section spacing / standard padding.
        static let lg: CGFloat = 16
        /// 20pt — generous section spacing.
        static let xl: CGFloat = 20
    }

    // MARK: - Corner Radius

    enum Radius {
        /// Small radius for compact cells.
        static let small: CGFloat = 6
        /// Standard card radius.
        static let card: CGFloat = 12
        /// Pill/capsule radius handled by Capsule().
    }

    // MARK: - Touch Targets

    enum TouchTarget {
        /// Minimum recommended tap target (Apple HIG ~44pt).
        static let minimum: CGFloat = 44
    }

    // MARK: - Calendar Cell

    enum CalendarCell {
        /// Minimum height for a month-view day cell (fits Dynamic Type reasonably).
        static let minHeight: CGFloat = 48
        /// Inter-cell spacing in the month grid.
        static let gridSpacing: CGFloat = 2
    }

    // MARK: - Borders

    enum Border {
        /// Hairline separator opacity.
        static let separatorOpacity: Double = 0.2
        /// Standard hairline width.
        static let width: CGFloat = 0.5
        /// Emphasis (today/selected) border width.
        static let emphasisWidth: CGFloat = 1.5
    }
}
