// ShiftFlow — App Entry Point
// App/ShiftFlowApp.swift
//
// TASK-FOUNDATION-001: Application entry point.
// TASK-CLOUDKIT-001: ModelContainer uses CloudKit-aware factory with fallback.
// TASK-INTEGRATION-001: Builds the AppContainer composition root and injects it.
//
// The main @App struct for ShiftFlow iOS application.

import SwiftUI
import SwiftData

@main
struct ShiftFlowApp: App {

    /// The application composition root.
    ///
    /// TASK-LOCAL-ONLY-IMPLEMENT-001: ShiftFlow is an explicitly LOCAL-ONLY
    /// product. The container is built with `useCloudKit: false`, so the local
    /// SwiftData store is the sole source of truth and no automatic iCloud/
    /// CloudKit synchronization is attempted or initialized. CloudKit support
    /// remains in `PersistenceConfiguration` but is intentionally unused here.
    /// The app is fully functional offline; manual data transfer is via CSV.
    @State private var container: AppContainer = AppContainer.makeDefault(useCloudKit: false)

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
        .modelContainer(container.modelContainer)
    }
}
