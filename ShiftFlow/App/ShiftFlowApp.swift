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
    /// Builds the CloudKit-aware ModelContainer (with local fallback) and wires
    /// all services together. The app remains fully functional offline.
    @State private var container: AppContainer = AppContainer.makeDefault(useCloudKit: true)

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
        .modelContainer(container.modelContainer)
    }
}
