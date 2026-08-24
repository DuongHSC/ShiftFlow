// ShiftFlow — Persistence Layer
// SwiftData/PersistenceContainer.swift
//
// TASK-FOUNDATION-001: SwiftData persistence foundation.
// TASK-CLOUDKIT-001: Added CloudKit synchronization configuration.
//
// This file establishes the persistence layer structure.
// The ModelContainer is configured in ShiftFlowApp.swift.
//
// Architecture constraint:
// The persistence layer serves the Application/Domain layers.
// UI must NOT directly perform database operations.
//
// LOCAL-FIRST:
// SwiftData is the primary source of truth. The app is fully usable offline.
// CloudKit is a synchronization layer only — it must never be required for
// the app to function.

import Foundation
import SwiftData

/// Persistence configuration for ShiftFlow.
///
/// The persistence container manages the SwiftData ModelContainer
/// and provides access patterns for the application.
enum PersistenceConfiguration {

    /// Planned App Group identifier for shared data access (App + Widget).
    /// Actual Xcode capability configuration must be completed on macOS/Xcode.
    static let plannedAppGroupIdentifier = "group.com.shiftflow.shared"

    /// Planned CloudKit container identifier.
    ///
    /// IMPORTANT: This is a PLACEHOLDER. The production CloudKit container
    /// must be created in the Apple Developer portal and configured in Xcode
    /// (Signing & Capabilities → iCloud → CloudKit). Not active on Windows.
    static let plannedCloudKitContainerIdentifier = "iCloud.com.shiftflow.app"

    /// The SwiftData schema (all @Model types).
    ///
    /// TASK-PERSISTENCE-001: Added ShiftDefinitionModel, ScheduleRuleModel,
    /// TaskDefinitionModel, WorkDayTaskModel. WorkDayModel remains the canonical
    /// persisted WorkDay. Adding these models is additive — existing WorkDay
    /// data and its snapshots are unaffected (SwiftData lightweight migration).
    static var schema: Schema {
        Schema([
            WorkDayModel.self,
            ShiftDefinitionModel.self,
            ScheduleRuleModel.self,
            TaskDefinitionModel.self,
            WorkDayTaskModel.self,
        ])
    }

    // MARK: - Local (Offline-First) Configuration

    /// Local-only configuration. The app is fully functional with this alone.
    ///
    /// - Parameter inMemory: Use in-memory store (for testing/previews).
    static func makeLocalConfiguration(inMemory: Bool = false) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: .none,          // App Group config pending Xcode
            cloudKitDatabase: .none         // Local-only variant
        )
    }

    // MARK: - CloudKit-Synced Configuration

    /// CloudKit-synced configuration.
    ///
    /// NOTE: This requires the iCloud/CloudKit capability enabled in Xcode
    /// and a valid CloudKit container. On Windows this is source-only and
    /// cannot be verified. The app must fall back to local operation if
    /// CloudKit is unavailable at runtime.
    ///
    /// SwiftData automatically merges CloudKit changes into the local store.
    /// It uses last-writer-wins at the field level; ShiftFlow adds an explicit
    /// `SyncConflictResolver` for WorkDay-level and date-collision integrity.
    static func makeCloudKitConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            // Automatic private-database sync via the configured container.
            cloudKitDatabase: .private(plannedCloudKitContainerIdentifier)
        )
    }

    // MARK: - Container Factory

    /// Builds the ModelContainer.
    ///
    /// Attempts CloudKit-synced configuration; if it fails (e.g., CloudKit
    /// unavailable, entitlement missing), falls back to a local-only store so
    /// the app remains usable offline.
    ///
    /// - Parameters:
    ///   - useCloudKit: Whether to attempt CloudKit sync.
    ///   - inMemory: Use in-memory store (testing).
    /// - Returns: A ModelContainer (never nil; falls back to local).
    static func makeContainer(useCloudKit: Bool = true, inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            return (try? ModelContainer(
                for: schema,
                configurations: [makeLocalConfiguration(inMemory: true)]
            )) ?? emptyFallback()
        }

        // CloudKit is gated at COMPILE TIME by the DISABLE_CLOUDKIT flag.
        //
        // Why compile-time rather than runtime entitlement inspection:
        // Creating a CloudKit-backed ModelContainer can SUCCEED and then trap at
        // runtime inside CloudKit ("BUG IN CLIENT OF CLOUDKIT ... requires the
        // com.apple.developer.icloud-services entitlement") when the build is not
        // signed with the iCloud capability — e.g. an unsigned CI simulator build
        // (CODE_SIGNING_ALLOWED=NO). That trap is not a catchable Swift error, so
        // `try?` cannot recover from it.
        //
        // The GitHub Actions unsigned Simulator build compiles with
        // `-D DISABLE_CLOUDKIT` (SWIFT_ACTIVE_COMPILATION_CONDITIONS), so the
        // CloudKit branch is removed entirely and the app uses the local store.
        // Signed production builds compile WITHOUT the flag and use CloudKit as
        // before. Behavior for real builds is unchanged.
        #if !DISABLE_CLOUDKIT
        if useCloudKit {
            if let cloudContainer = try? ModelContainer(
                for: schema,
                configurations: [makeCloudKitConfiguration()]
            ) {
                return cloudContainer
            }
            // CloudKit unavailable — fall back to local so the app still works.
        }
        #endif

        return (try? ModelContainer(
            for: schema,
            configurations: [makeLocalConfiguration(inMemory: false)]
        )) ?? emptyFallback()
    }

    /// Last-resort in-memory container so the app never crashes on launch.
    private static func emptyFallback() -> ModelContainer {
        // If even this fails, the app has a fundamental problem; force-unwrap
        // here is the documented last resort.
        try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }
}
