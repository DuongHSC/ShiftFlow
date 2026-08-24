// ShiftFlow — Domain Layer
// Services/SyncModels.swift
//
// TASK-CLOUDKIT-001: Sync status models (CloudKit-agnostic).
//
// Defines the user-facing sync state and a protocol the app uses to observe it.
// The domain does NOT import CloudKit — concrete implementation lives in the app.

import Foundation

/// User-facing synchronization status.
/// UI must present these as simple states — never raw CloudKit error codes.
public enum SyncStatus: Equatable, Sendable {
    /// All local changes are synced to iCloud.
    case synced
    /// Sync is currently in progress.
    case syncing
    /// Waiting for a network connection.
    case waitingForConnection
    /// Sync is temporarily unavailable (will retry).
    case unavailable
    /// iCloud account is not available / not signed in.
    case accountUnavailable

    /// Vietnamese display text for the UI.
    public var displayText: String {
        switch self {
        case .synced: return "Đã đồng bộ"
        case .syncing: return "Đang đồng bộ…"
        case .waitingForConnection: return "Chờ kết nối"
        case .unavailable: return "Đồng bộ tạm ngừng"
        case .accountUnavailable: return "Chưa đăng nhập iCloud"
        }
    }

    /// Whether local data remains fully usable in this state (always true).
    public var localDataUsable: Bool { true }
}

/// Observes and reports the current sync status.
/// Concrete implementation (in the app) bridges CloudKit/SwiftData sync events.
public protocol SyncStatusObserving: AnyObject {
    /// The current sync status.
    var currentStatus: SyncStatus { get }
    /// Registers a callback invoked when the status changes.
    func onStatusChange(_ handler: @escaping (SyncStatus) -> Void)
}
