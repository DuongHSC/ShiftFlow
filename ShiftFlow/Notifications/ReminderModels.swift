// ShiftFlow — Notifications Layer
// ReminderModels.swift
//
// TASK-REMINDER-001: Reminder configuration models.
//
// CRITICAL RULES:
// - Reminder timing is based ONLY on WorkDay.resolvedStartDateTime.
// - ReminderService must NEVER calculate shift times independently.
// - Task/MW/Note do NOT influence reminder timing.
// - OFF = no WorkDay = no reminder.
// - "24 hours before" = exactly 24 hours before resolvedStartDateTime.

import Foundation

// MARK: - Reminder Offset

/// Supported reminder offsets relative to WorkDay.resolvedStartDateTime.
public enum ReminderOffset: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Notification at the exact shift start time.
    case atStart = "at_start"
    /// 30 minutes before shift start.
    case thirtyMinutesBefore = "30min"
    /// 1 hour before shift start.
    case oneHourBefore = "1h"
    /// 2 hours before shift start.
    case twoHoursBefore = "2h"
    /// Exactly 24 hours before shift start.
    case twentyFourHoursBefore = "24h"

    public var id: String { rawValue }

    /// The time interval offset (negative = before start).
    public var timeInterval: TimeInterval {
        switch self {
        case .atStart: return 0
        case .thirtyMinutesBefore: return -30 * 60
        case .oneHourBefore: return -60 * 60
        case .twoHoursBefore: return -2 * 60 * 60
        case .twentyFourHoursBefore: return -24 * 60 * 60
        }
    }

    /// Vietnamese display name for UI.
    public var displayName: String {
        switch self {
        case .atStart: return "Lúc bắt đầu"
        case .thirtyMinutesBefore: return "30 phút trước"
        case .oneHourBefore: return "1 giờ trước"
        case .twoHoursBefore: return "2 giờ trước"
        case .twentyFourHoursBefore: return "24 giờ trước"
        }
    }

    /// Calculates the notification fire date from a resolved start time.
    ///
    /// - Parameter resolvedStart: The WorkDay's resolvedStartDateTime.
    /// - Returns: The date/time when the notification should fire.
    public func notificationDate(from resolvedStart: Date) -> Date {
        resolvedStart.addingTimeInterval(timeInterval)
    }
}

// MARK: - Reminder Configuration

/// Reminder configuration for a specific WorkDay.
///
/// Source of truth for timing: WorkDay.resolvedStartDateTime + offset.
/// The calculated notification time is NOT stored as source of truth.
public struct ReminderConfiguration: Identifiable, Equatable, Codable, Sendable {

    public let id: UUID

    /// Reference to the WorkDay this reminder belongs to.
    public let workDayID: UUID

    /// The selected reminder offset.
    public var offset: ReminderOffset

    /// Whether the reminder is enabled.
    public var isEnabled: Bool

    /// The deterministic notification identifier.
    /// Format: "shiftflow.workday.<workDayID>.<offset>"
    public var notificationIdentifier: String {
        "shiftflow.workday.\(workDayID.uuidString).\(offset.rawValue)"
    }

    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        workDayID: UUID,
        offset: ReminderOffset,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.workDayID = workDayID
        self.offset = offset
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Returns a new configuration with updated offset.
    public func withOffset(_ newOffset: ReminderOffset) -> ReminderConfiguration {
        var copy = self
        copy.offset = newOffset
        copy.modifiedAt = Date()
        return copy
    }

    /// Returns a new configuration with enabled/disabled state.
    public func withEnabled(_ enabled: Bool) -> ReminderConfiguration {
        var copy = self
        copy.isEnabled = enabled
        copy.modifiedAt = Date()
        return copy
    }
}

// MARK: - Notification Identifier Helpers

/// Helpers for generating and parsing ShiftFlow notification identifiers.
public enum ReminderIdentifier {

    /// Prefix for all ShiftFlow notification identifiers.
    public static let prefix = "shiftflow.workday."

    /// Generates a deterministic notification identifier.
    public static func make(workDayID: UUID, offset: ReminderOffset) -> String {
        "\(prefix)\(workDayID.uuidString).\(offset.rawValue)"
    }

    /// Checks whether a notification identifier belongs to ShiftFlow.
    public static func isShiftFlowNotification(_ identifier: String) -> Bool {
        identifier.hasPrefix(prefix)
    }

    /// Extracts the WorkDay ID from a ShiftFlow notification identifier.
    /// Returns nil if the identifier is not a valid ShiftFlow identifier.
    public static func extractWorkDayID(_ identifier: String) -> UUID? {
        guard isShiftFlowNotification(identifier) else { return nil }
        let withoutPrefix = String(identifier.dropFirst(prefix.count))
        // Format: <UUID>.<offset>
        let parts = withoutPrefix.split(separator: ".", maxSplits: 1)
        guard let uuidPart = parts.first else { return nil }
        return UUID(uuidString: String(uuidPart))
    }

    /// Generates all possible identifiers for a WorkDay (all offsets).
    public static func allIdentifiers(for workDayID: UUID) -> [String] {
        ReminderOffset.allCases.map { make(workDayID: workDayID, offset: $0) }
    }
}

// MARK: - Reminder Scheduling Result

/// Result of a reminder scheduling operation.
public enum ReminderSchedulingResult: Equatable, Sendable {
    /// Successfully scheduled.
    case scheduled(identifier: String, fireDate: Date)
    /// Skipped because fire date is in the past.
    case skippedPast
    /// Skipped because permission is denied.
    case permissionDenied
    /// Skipped because reminder is disabled.
    case disabled
    /// Failed with an error description.
    case failed(String)
}

// MARK: - Notification Permission Status

/// Represents the current notification authorization status.
public enum NotificationPermissionStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case provisional
}
