// ShiftFlow — Domain Layer
// ShiftFlowDomain.swift
//
// Public module entry point for the shared domain package.
// This module is imported by:
// - Main iOS application
// - Widget extension
// - Unit tests
//
// IMPORTANT: This module must NOT depend on:
// - SwiftUI
// - WidgetKit
// - UserNotifications
// - CloudKit
//
// It contains only pure domain logic: models, services, and rules.

import Foundation

/// ShiftFlowDomain module marker.
/// Provides shift schedule resolution, models, and business rules.
public enum ShiftFlowDomain {
    /// Current domain module version.
    public static let version = "0.1.3"
}
