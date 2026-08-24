// ShiftFlow — Notifications Layer
// NotificationService.swift
//
// TASK-FOUNDATION-001: Directory placeholder.
// Full implementation belongs to TASK-REMINDER-001.
//
// NotificationService is responsible for:
// - Requesting notification permission
// - Scheduling shift reminders using resolved WorkDay data
// - Canceling stale reminders when a WorkDay changes/is deleted
// - Managing the rolling 7–14 day scheduling window
// - Using deterministic notification identifiers (shiftflow.reminder.<workday-id>)
//
// IMPORTANT:
// - NotificationService must NOT independently calculate shift times.
// - It receives resolved schedule information from the Domain layer.
// - Notifications are device-local and NOT synced via CloudKit.

import Foundation

/// Placeholder — NotificationService will be implemented in TASK-REMINDER-001.
enum NotificationServicePlaceholder {
    // Intentionally empty.
}
