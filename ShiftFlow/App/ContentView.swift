// ShiftFlow — App
// App/ContentView.swift
//
// TASK-INTEGRATION-001: Root content view wired to the Calendar screen.
// TASK-SETTINGS-001: Added Settings tab.
//
// Hosts the integrated Calendar UI + Settings, backed by AppContainer.

import SwiftUI
import SwiftData

struct ContentView: View {
    /// The composition root, built from the shared model container.
    @State private var container: AppContainer

    init(container: AppContainer) {
        _container = State(initialValue: container)
    }

    var body: some View {
        TabView {
            CalendarScreen(
                viewModel: container.calendarViewModel,
                shiftLookup: container.shiftLookup,
                workDayService: container.workDayService,
                taskService: container.taskService
            )
            .tabItem {
                Label("Lịch", systemImage: "calendar")
            }

            SettingsScreen(
                viewModel: container.settingsViewModel,
                taskViewModel: container.taskSettingsViewModel,
                dataViewModel: container.dataManagementViewModel
            )
            .tabItem {
                Label("Cài đặt", systemImage: "gearshape")
            }
        }
    }
}
