// ShiftFlow — Application Layer
// AppContainer.swift
//
// TASK-INTEGRATION-001: Composition root.
//
// Wires all ShiftFlow modules into one coherent application:
// - SwiftData repository (local persistence, primary source of truth)
// - WorkDayService (CRUD + ShiftResolver + snapshot)
// - WidgetRefreshCoordinator + AppGroupWidgetSnapshotSink (widget refresh)
// - ShiftImportService / ShiftExportService (XLSX import/export)
// - ReminderService (local notifications)
// - CloudSyncService (CloudKit side-effects)
// - ShiftDefinitionProvider (shift lookup)
// - CalendarViewModel (UI state)
//
// DEPENDENCY DIRECTION: UI → Application → Domain → Persistence.
//
// SECONDARY-OPERATION RULE:
// Persistence succeeds first. Widget/Reminder/CloudKit are secondary and
// never fail or roll back a WorkDay operation.

import Foundation
import SwiftData
import ShiftFlowDomain

/// The application composition root. Builds and holds the wired services.
@MainActor
public final class AppContainer {

    // MARK: - Persistence

    public let modelContainer: ModelContainer
    public let repository: WorkDayRepository

    // MARK: - Domain / Application Services

    public let workDayService: WorkDayService
    public let importService: ShiftImportService
    public let exportService: ShiftExportService
    public let shiftProvider: ShiftDefinitionProvider
    public let configurationService: ShiftConfigurationService
    public let taskService: TaskService

    // MARK: - Integration Services

    public let widgetRefresher: WidgetRefreshCoordinator
    public let reminderService: ReminderService
    public let cloudSyncService: CloudSyncService

    // MARK: - View Models

    public let calendarViewModel: CalendarViewModel
    public let settingsViewModel: ShiftSettingsViewModel
    public let taskSettingsViewModel: TaskSettingsViewModel
    public let dataManagementViewModel: DataManagementViewModel

    // MARK: - Initialization

    /// Builds the full application graph.
    ///
    /// - Parameters:
    ///   - modelContainer: The SwiftData container (CloudKit-aware or local).
    ///   - calendar: Calendar for date operations.
    ///   - widgetSink: The widget snapshot sink (App Group + WidgetKit reload).
    /// Builds the full application graph.
    ///
    /// - Parameters:
    ///   - modelContainer: The SwiftData container (CloudKit-aware or local).
    ///   - calendar: Calendar for date operations.
    ///   - widgetSink: The widget snapshot sink (App Group + WidgetKit reload).
    ///   - configStore: Optional configuration store (defaults to SwiftData-backed).
    ///     Tests may inject `InMemoryShiftConfigurationStore`.
    ///   - taskStore: Optional task store (defaults to SwiftData-backed).
    ///     Tests may inject `InMemoryTaskStore`.
    public init(
        modelContainer: ModelContainer,
        calendar: Calendar = .current,
        widgetSink: WidgetSnapshotSink = AppGroupWidgetSnapshotSink(),
        configStore: ShiftConfigurationStore? = nil,
        taskStore: TaskStore? = nil
    ) {
        self.modelContainer = modelContainer

        // Persistence: SwiftData-backed repository (primary source of truth).
        let repo = SwiftDataWorkDayRepository(
            modelContext: modelContainer.mainContext,
            calendar: calendar
        )
        self.repository = repo

        // Task service (TaskDefinition + WorkDayTask), SwiftData-backed by default.
        // Seeds MW idempotently — surviving definitions/assignments are preserved.
        let resolvedTaskStore: TaskStore = taskStore
            ?? SwiftDataTaskStore(modelContext: modelContainer.mainContext)
        let tasks = TaskService(store: resolvedTaskStore)
        tasks.seedIfNeeded()
        self.taskService = tasks

        // Widget refresh coordinator (rebuilds snapshot from repository).
        // Task indicator provider reflects real WorkDay→task assignments.
        let refresher = WidgetRefreshCoordinator(
            repository: repo,
            sink: widgetSink,
            taskWorkDayIDsProvider: { tasks.workDayIDsWithTasks() },
            calendar: calendar
        )
        self.widgetRefresher = refresher

        // WorkDayService with widget refresh wired in (secondary operation).
        let wdService = WorkDayService(
            repository: repo,
            calendar: calendar,
            widgetRefresher: refresher
        )
        self.workDayService = wdService

        // Shift configuration service (user-editable definitions/rules),
        // SwiftData-backed by default. Seeds C1–C5 + C5 rule idempotently on
        // first run — existing custom configuration is preserved across launches.
        let resolvedConfigStore: ShiftConfigurationStore = configStore
            ?? SwiftDataShiftConfigurationStore(modelContext: modelContainer.mainContext)
        let configService = ShiftConfigurationService(store: resolvedConfigStore)
        configService.seedIfNeeded()
        self.configurationService = configService

        // Shift definition provider backed by the configuration service
        // (so config edits affect FUTURE WorkDay resolution).
        let provider = ShiftDefinitionProvider(configurationService: configService)
        self.shiftProvider = provider

        // Import / Export services (import validates + assigns tasks).
        self.importService = ShiftImportService(
            workDayService: wdService,
            shiftLookup: provider.lookupClosure,
            taskService: tasks,
            calendar: calendar
        )
        self.exportService = ShiftExportService(calendar: calendar)

        // Reminder service (local notifications).
        self.reminderService = ReminderService(calendar: calendar)

        // CloudKit sync coordination (widget refresh + integrity after sync).
        self.cloudSyncService = CloudSyncService(
            repository: repo,
            widgetRefresher: refresher,
            calendar: calendar
        )

        // Calendar view model (UI state).
        self.calendarViewModel = CalendarViewModel(
            workDayService: wdService,
            calendar: calendar
        )

        // Settings view models.
        self.settingsViewModel = ShiftSettingsViewModel(
            configurationService: configService
        )
        self.taskSettingsViewModel = TaskSettingsViewModel(
            taskService: tasks
        )

        // Data management view model (CSV import/export UI) — reuses the
        // existing import/export services (TASK-DATA-001).
        self.dataManagementViewModel = DataManagementViewModel(
            importService: self.importService,
            exportService: self.exportService,
            workDayService: wdService,
            taskService: tasks,
            calendar: calendar
        )
    }

    // MARK: - Convenience Builders

    /// Builds an AppContainer from the app's shared configuration.
    public static func makeDefault(useCloudKit: Bool = true) -> AppContainer {
        let container = PersistenceConfiguration.makeContainer(useCloudKit: useCloudKit)
        return AppContainer(modelContainer: container)
    }

    /// The shift lookup closure, exposed for the Day Detail sheet.
    public var shiftLookup: (String) -> (shift: ShiftDefinition, rules: [ScheduleRule])? {
        shiftProvider.lookupClosure
    }
}
