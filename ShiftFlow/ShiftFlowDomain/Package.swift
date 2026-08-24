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
        // TASK-XCODE-FIX-001 (XP-01):
        // Four test files exercise application-layer ViewModels
        // (CalendarViewModel, DataManagementViewModel, TaskSettingsViewModel,
        // ShiftSettingsViewModel) that live in the ShiftFlow app module, not this
        // package. They `@testable import ShiftFlow`, which SPM cannot resolve for
        // the standalone package. They are therefore EXCLUDED from this SPM test
        // target and are compiled instead by the app-hosted `ShiftFlowTests` Xcode
        // target (which links both the app and this package).
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
                "ShiftSettingsTests.swift"
            ]
        )
    ]
)
