// ShiftFlow — Persistence Layer (CloudKit)
// CloudKit/CloudSyncService.swift
//
// TASK-CLOUDKIT-001: CloudKit synchronization coordination.
//
// This service observes SwiftData/CloudKit remote-change notifications and:
// 1. Lets SwiftData merge remote changes into the local store (automatic).
// 2. Runs post-sync integrity checks (date-collision resolution).
// 3. Rebuilds the Widget snapshot after relevant WorkDay changes.
// 4. Reports a user-facing SyncStatus.
//
// CRITICAL RULES:
// - CloudKit is synchronization only. SwiftData local store is source of truth.
// - NEVER recalculate WorkDay snapshots from ShiftDefinition during sync.
// - NEVER synchronize notification requests or the Widget App Group snapshot.
// - App must remain fully usable if CloudKit is unavailable.

import Foundation
import SwiftData
import ShiftFlowDomain
import os

/// Coordinates CloudKit synchronization side-effects and reports sync status.
///
/// NOTE: Actual CloudKit sync is performed automatically by SwiftData when the
/// container is configured with `cloudKitDatabase`. This service reacts to
/// remote-change notifications; it does not implement a custom sync engine.
public final class CloudSyncService: SyncStatusObserving {

    private let logger = Logger(subsystem: "com.shiftflow.app", category: "CloudSync")

    /// The WorkDay repository (SwiftData-backed).
    private let repository: WorkDayRepository

    /// Coordinator that rebuilds/publishes the widget snapshot.
    private let widgetRefresher: WidgetRefreshCoordinator?

    /// Calendar for date-collision checks.
    private let calendar: Calendar

    // MARK: - SyncStatusObserving

    public private(set) var currentStatus: SyncStatus = .synced {
        didSet {
            if oldValue != currentStatus {
                statusChangeHandler?(currentStatus)
            }
        }
    }

    private var statusChangeHandler: ((SyncStatus) -> Void)?

    public func onStatusChange(_ handler: @escaping (SyncStatus) -> Void) {
        statusChangeHandler = handler
    }

    // MARK: - Initialization

    public init(
        repository: WorkDayRepository,
        widgetRefresher: WidgetRefreshCoordinator?,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.widgetRefresher = widgetRefresher
        self.calendar = calendar
    }

    // MARK: - Sync Lifecycle Hooks

    /// Called when a remote sync begins.
    public func syncDidStart() {
        currentStatus = .syncing
    }

    /// Called when SwiftData has merged remote changes into the local store.
    ///
    /// Performs integrity checks and refreshes the widget. Does NOT recalculate
    /// any WorkDay snapshot.
    public func syncDidComplete() {
        // Post-sync integrity: resolve any date collisions deterministically.
        resolveDateCollisionsIfNeeded()

        // Rebuild the widget snapshot from the (now-updated) local store.
        widgetRefresher?.refresh()

        currentStatus = .synced
    }

    /// Called when sync fails or CloudKit is unavailable.
    /// Local data remains fully usable.
    public func syncDidFail(reason: SyncFailureReason) {
        switch reason {
        case .networkUnavailable:
            currentStatus = .waitingForConnection
        case .accountUnavailable:
            currentStatus = .accountUnavailable
        case .temporary, .other:
            currentStatus = .unavailable
        }
        logger.error("CloudKit sync unavailable: \(String(describing: reason)). Local data remains usable.")
    }

    // MARK: - Date-Collision Resolution

    /// Detects and resolves "two WorkDays on the same date" that sync may create.
    ///
    /// Keeps exactly one WorkDay per date (last-modified wins). Does NOT
    /// recalculate the winner's snapshot.
    private func resolveDateCollisionsIfNeeded() {
        let today = calendar.startOfDay(for: Date())
        let windowEnd = calendar.date(byAdding: .day, value: 365, to: today) ?? today
        let windowStart = calendar.date(byAdding: .day, value: -365, to: today) ?? today

        let workDays: [WorkDay]
        do {
            workDays = try repository.fetchByDateRange(from: windowStart, to: windowEnd)
        } catch {
            // Can't read — leave as-is; do not crash.
            return
        }

        let collisions = SyncConflictResolver.detectDateCollisions(
            workDays: workDays, calendar: calendar
        )

        for group in collisions {
            let (winner, losers) = SyncConflictResolver.resolveDateCollision(candidates: group)
            guard winner != nil else { continue }
            for loser in losers {
                // Remove the losing duplicate. Winner's snapshot preserved.
                try? repository.delete(loser.id)
                logger.debug("Resolved date collision: removed duplicate WorkDay.")
            }
        }
    }
}

/// Reasons a CloudKit sync may fail.
public enum SyncFailureReason: Equatable, Sendable {
    case networkUnavailable
    case accountUnavailable
    case temporary
    case other
}
