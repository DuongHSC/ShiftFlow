// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ShiftFlowDomain",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ShiftFlowDomain",
            targets: ["ShiftFlowDomain"]
        )
    ],
    targets: [
        .target(
            name: "ShiftFlowDomain",
            dependencies: [],
            path: "Sources"
        ),
        // TASK-XCODE-FIX-001 (XP-01) + TASK-GITHUB-ACTIONS-FIX-004:
        // Some test files exercise types that live in the ShiftFlow APP module,
        // not this package:
        //   - ViewModels: CalendarViewModel, DataManagementViewModel,
        //     TaskSettingsViewModel, ShiftSettingsViewModel
        //   - Reminders: ReminderOffset, ReminderConfiguration, ReminderIdentifier
        //     (Notifications/ReminderModels.swift)
        //   - UI helpers: WeekdayFormatter, AccessibilityLabelBuilder (UI/Shared/)
        // These files `@testable import ShiftFlow`, which SPM cannot resolve for the
        // standalone package. They are therefore EXCLUDED from this SPM test target
        // and are compiled instead by the app-hosted `ShiftFlowTests` Xcode target
        // (which links both the app and this package).
        //
        // The application source is NOT moved; only test-target membership differs
        // between the SPM package and the Xcode project.
        .testTarget(
            name: "ShiftFlowDomainTests",
            dependencies: ["ShiftFlowDomain"],
            path: "Tests",
            exclude: [
                "CalendarViewModelTests.swift",
                "DataManagementViewModelTests.swift",
                "TaskSettingsViewModelTests.swift",
                "ShiftSettingsTests.swift",
                "ReminderTests.swift",
                "PolishTests.swift"
            ]
        )
    ]
)
