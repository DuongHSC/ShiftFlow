// ShiftFlow — Notifications Layer
// ReminderService.swift
//
// TASK-REMINDER-001: Local notification scheduling service.
//
// ARCHITECTURE:
// WorkDay.resolvedStartDateTime → ReminderService → UNUserNotificationCenter
//
// CRITICAL RULES:
// - NEVER calculate shift times. Use WorkDay.resolvedStartDateTime only.
// - NEVER reference ShiftResolver, ScheduleRule, or C5 logic.
// - Task/MW/Note do NOT influence reminder timing.
// - Rolling window: schedule only next 14 days.
// - Respect iOS 64 pending notification limit (use safety margin).
// - Deterministic identifiers for cancel/replace.
// - Cancel all WorkDay reminders on deletion.
// - Do not leave stale notifications.

import Foundation
import UserNotifications
import ShiftFlowDomain

/// Service responsible for scheduling and managing local shift reminders.
///
/// Usage:
/// ```swift
/// let service = ReminderService()
/// await service.scheduleReminder(for: workDay, offset: .twoHoursBefore)
/// await service.cancelReminders(for: workDayID)
/// await service.refreshSchedulingWindow(workDays: upcoming)
/// ```
public final class ReminderService {

    // MARK: - Configuration

    /// Rolling window: schedule reminders for the next N days.
    public static let schedulingWindowDays: Int = 14

    /// Safety margin below iOS 64 pending notification limit.
    /// ShiftFlow will schedule at most this many notifications.
    public static let maxPendingNotifications: Int = 50

    /// ShiftFlow notification category identifier.
    public static let categoryIdentifier = "shiftflow.shift.reminder"

    // MARK: - Dependencies

    private let notificationCenter: UNUserNotificationCenter
    private let calendar: Calendar

    // MARK: - Initialization

    public init(
        notificationCenter: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    // MARK: - Permission

    /// Requests notification authorization.
    /// Returns the resulting permission status.
    @MainActor
    public func requestPermission() async -> NotificationPermissionStatus {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    /// Checks current notification authorization status.
    public func checkPermission() async -> NotificationPermissionStatus {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .provisional: return .provisional
        case .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }

    // MARK: - Schedule Single Reminder

    /// Schedules a reminder for a specific WorkDay and offset.
    ///
    /// - Parameters:
    ///   - workDay: The WorkDay containing resolvedStartDateTime.
    ///   - offset: The reminder offset (e.g., 2 hours before).
    /// - Returns: The scheduling result.
    public func scheduleReminder(
        for workDay: WorkDay,
        offset: ReminderOffset
    ) async -> ReminderSchedulingResult {
        // Check permission.
        let permission = await checkPermission()
        guard permission == .authorized || permission == .provisional else {
            return .permissionDenied
        }

        // Calculate notification fire date from resolved start time.
        let fireDate = offset.notificationDate(from: workDay.resolvedStartDateTime)

        // Do not schedule past notifications.
        if fireDate <= Date() {
            return .skippedPast
        }

        // Build notification content.
        let content = buildNotificationContent(for: workDay, offset: offset)

        // Build trigger.
        let triggerComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        // Deterministic identifier.
        let identifier = ReminderIdentifier.make(workDayID: workDay.id, offset: offset)

        // Create request.
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Schedule.
        do {
            try await notificationCenter.add(request)
            return .scheduled(identifier: identifier, fireDate: fireDate)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Cancel Reminders

    /// Cancels all reminders for a specific WorkDay.
    /// Called when a WorkDay is deleted or shift changes.
    public func cancelReminders(for workDayID: UUID) {
        let identifiers = ReminderIdentifier.allIdentifiers(for: workDayID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Cancels a specific reminder by offset.
    public func cancelReminder(for workDayID: UUID, offset: ReminderOffset) {
        let identifier = ReminderIdentifier.make(workDayID: workDayID, offset: offset)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancels ALL ShiftFlow notifications (used during full refresh).
    public func cancelAllShiftFlowNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let shiftFlowIDs = pending
            .map(\.identifier)
            .filter { ReminderIdentifier.isShiftFlowNotification($0) }

        if !shiftFlowIDs.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: shiftFlowIDs)
        }
    }

    // MARK: - Rolling Window Refresh

    /// Refreshes the reminder scheduling window.
    ///
    /// Strategy:
    /// 1. Cancel all existing ShiftFlow notifications.
    /// 2. Filter WorkDays within the next 14 days.
    /// 3. Schedule reminders for each WorkDay that has an enabled reminder.
    /// 4. Respect the max pending notification limit.
    ///
    /// - Parameters:
    ///   - workDays: All WorkDays to consider (should include upcoming 14 days).
    ///   - reminderConfigs: Reminder configurations for the WorkDays.
    /// - Returns: Number of notifications successfully scheduled.
    public func refreshSchedulingWindow(
        workDays: [WorkDay],
        reminderConfigs: [UUID: ReminderConfiguration]
    ) async -> Int {
        // Step 1: Cancel all existing ShiftFlow notifications.
        await cancelAllShiftFlowNotifications()

        // Step 2: Check permission.
        let permission = await checkPermission()
        guard permission == .authorized || permission == .provisional else {
            return 0
        }

        // Step 3: Filter to rolling window (next 14 days).
        let now = Date()
        let windowEnd = calendar.date(byAdding: .day, value: Self.schedulingWindowDays, to: now)!
        let upcoming = workDays.filter { workDay in
            workDay.resolvedStartDateTime > now &&
            workDay.resolvedStartDateTime <= windowEnd
        }

        // Step 4: Schedule reminders (respecting limit).
        var scheduled = 0

        for workDay in upcoming {
            guard scheduled < Self.maxPendingNotifications else { break }

            // Check if this WorkDay has an enabled reminder config.
            guard let config = reminderConfigs[workDay.id],
                  config.isEnabled else {
                continue
            }

            let result = await scheduleReminder(for: workDay, offset: config.offset)
            if case .scheduled = result {
                scheduled += 1
            }
        }

        return scheduled
    }

    // MARK: - Reschedule After Shift Change

    /// Reschedules reminders after a WorkDay's shift has changed.
    ///
    /// Flow:
    /// 1. Cancel old notifications for this WorkDay.
    /// 2. Schedule new notification with updated resolvedStartDateTime.
    ///
    /// - Parameters:
    ///   - workDay: The updated WorkDay with new resolved times.
    ///   - config: The reminder configuration for this WorkDay.
    /// - Returns: The scheduling result.
    public func rescheduleAfterShiftChange(
        workDay: WorkDay,
        config: ReminderConfiguration
    ) async -> ReminderSchedulingResult {
        // Cancel all old notifications for this WorkDay.
        cancelReminders(for: workDay.id)

        // If disabled, we're done.
        guard config.isEnabled else {
            return .disabled
        }

        // Schedule with new times.
        return await scheduleReminder(for: workDay, offset: config.offset)
    }

    // MARK: - Pending Count

    /// Returns the current count of pending ShiftFlow notifications.
    public func pendingShiftFlowCount() async -> Int {
        let pending = await notificationCenter.pendingNotificationRequests()
        return pending.filter { ReminderIdentifier.isShiftFlowNotification($0.identifier) }.count
    }

    // MARK: - Private Helpers

    /// Builds the notification content for a shift reminder.
    private func buildNotificationContent(
        for workDay: WorkDay,
        offset: ReminderOffset
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        let timeString = TimeFormatter.format(workDay.resolvedStartDateTime)

        switch offset {
        case .atStart:
            content.title = "ShiftFlow"
            content.body = "\(workDay.shiftCode) bắt đầu lúc \(timeString)."
        case .thirtyMinutesBefore:
            content.title = "ShiftFlow — 30 phút nữa"
            content.body = "\(workDay.shiftCode) bắt đầu lúc \(timeString)."
        case .oneHourBefore:
            content.title = "ShiftFlow — 1 giờ nữa"
            content.body = "\(workDay.shiftCode) bắt đầu lúc \(timeString)."
        case .twoHoursBefore:
            content.title = "ShiftFlow — 2 giờ nữa"
            content.body = "\(workDay.shiftCode) bắt đầu lúc \(timeString)."
        case .twentyFourHoursBefore:
            content.title = "ShiftFlow — Ngày mai"
            content.body = "\(workDay.shiftCode) bắt đầu lúc \(timeString)."
        }

        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        return content
    }
}

// TASK-GITHUB-ACTIONS-FIX-004:
// The previously-duplicated `private enum TimeFormatter` was removed to fix an
// "invalid redeclaration of 'TimeFormatter'" error — it collided with the
// existing shared `TimeFormatter` (UI/Shared/TimeFormatter.swift) in the same
// app module. `buildNotificationContent` reuses that shared, functionally
// equivalent `TimeFormatter.format(_:)`. Reminder behavior is unchanged.
