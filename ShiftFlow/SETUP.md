# ShiftFlow — Xcode Project Setup Guide

## Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- iOS 17.0 deployment target

## Setup Steps

### 1. Create Xcode Project

1. Open Xcode → File → New → Project
2. Select **iOS** → **App**
3. Product Name: `ShiftFlow`
4. Interface: **SwiftUI**
5. Storage: **SwiftData**
6. Include Tests: **Yes**
7. Save to the `ShiftFlow/` directory (replace the placeholder .xcodeproj)

### 2. Configure Project Structure

Move or link the source files into the Xcode project:

```
App/                    → Main app target sources
Application/            → Main app target sources
Persistence/            → Main app target sources
UI/                     → Main app target sources
Notifications/          → Main app target sources
Tests/                  → ShiftFlowTests target
```

### 3. Add Local Domain Package

1. File → Add Package Dependencies...
2. Click "Add Local..."
3. Navigate to `ShiftFlowDomain/` directory
4. Add to both the main app target and widget target

### 4. Add Widget Extension (later task)

1. File → New → Target
2. Select **Widget Extension**
3. Name: `ShiftFlowWidget`
4. Add `ShiftFlowDomain` package dependency to this target

### 5. Configure App Group

1. Select ShiftFlow target → Signing & Capabilities
2. Add App Groups capability
3. Add group: `group.com.shiftflow.shared`
4. Repeat for Widget target

### 6. Verify Build

1. Select iPhone 15 simulator
2. ⌘B to build
3. ⌘U to run tests

## Architecture Verification

After setup, verify:

- [ ] Main app builds successfully
- [ ] `import ShiftFlowDomain` works in main app
- [ ] ShiftFlowDomain package compiles independently
- [ ] Test target runs and passes basic test
- [ ] Domain module does NOT import SwiftUI/WidgetKit/CloudKit/UserNotifications

---

## TASK-XCODE-PROJECT-001 — Generated Xcode Project (v0.9.2)

A real, structured `ShiftFlow.xcodeproj` has now been generated (replacing the
previous placeholder). It was authored on a Windows host and has NOT been
opened or built by Xcode. Build/test/runtime verification remains **PENDING ON
macOS/Xcode**.

### Targets

| Target | Product type | Bundle ID | Notes |
|--------|--------------|-----------|-------|
| `ShiftFlow` | iOS App | `com.shiftflow.app` | Links `ShiftFlowDomain` local SPM package |
| `ShiftFlowWidgetExtension` | Widget (app-extension) | `com.shiftflow.app.widget` | Links `ShiftFlowDomain`; embedded in the app |
| `ShiftFlowTests` | Unit test bundle | `com.shiftflow.app.tests` | Hosted by the app (`TEST_HOST` = ShiftFlow.app) |

- Deployment target: **iOS 17.0** (matches `ShiftFlowDomain/Package.swift` `.iOS(.v17)`).
- Swift language version: **5.0** setting (source is Swift 5.9-compatible).
- Local Swift Package: `ShiftFlowDomain` referenced via `XCLocalSwiftPackageReference`.
- Shared scheme `ShiftFlow` builds the app + widget and runs `ShiftFlowTests`.

### Source membership

- App target: `App/`, `Application/**`, `Notifications/`, `Persistence/**`,
  `UI/**`, and `Widget/Services/AppGroupWidgetSnapshotSink.swift` +
  `Widget/Services/WidgetDataProvider.swift` (shared write/read side used by the app sink).
- Widget target: `Widget/ShiftFlowWidget.swift`, `ShiftFlowWidgetBundle.swift`,
  `Widget/Providers/*`, `Widget/Views/*`, `Widget/Services/WidgetDataProvider.swift`.
- Test target: `Tests/ShiftFlowTests.swift` + all `ShiftFlowDomain/Tests/*.swift`.
- Domain models/services (ShiftResolver, WorkDay, TaskDefinition, snapshot models,
  import/export, etc.) come from the `ShiftFlowDomain` package (no duplication).

### Capabilities (configuration written; physical enablement PENDING signing)

- App Group `group.com.shiftflow.shared` — in `App/ShiftFlow.entitlements` and
  `Widget/ShiftFlowWidget.entitlements`.
- iCloud / CloudKit container `iCloud.com.shiftflow.app` + `aps-environment` —
  in `App/ShiftFlow.entitlements`.
- URL scheme `shiftflow` (deep link `shiftflow://day?date=yyyy-MM-dd`) — in `App/Info.plist`.
- **SIGNING PENDING:** no Apple Developer Team is configured. `CODE_SIGN_STYLE = Automatic`;
  a Team must be selected in Xcode. Capabilities are declared but not physically
  provisioned. Do not treat sync/App-Group as verified until signed on macOS.

### KNOWN ISSUE — Test target module imports (REQUIRES DECISION on macOS)

The files in `ShiftFlowDomain/Tests/` use `@testable import ShiftFlowDomain`, but
four of them reference **application-layer** types that live in `Application/ViewModels/`
(NOT in the domain package):

- `CalendarViewModelTests.swift` → `CalendarViewModel`
- `DataManagementViewModelTests.swift` → `DataManagementViewModel`
- `TaskSettingsViewModelTests.swift` → `TaskSettingsViewModel`
- `ShiftSettingsTests.swift` → `CalendarViewModel`, `ShiftSettingsViewModel`

These app types are compiled into the `ShiftFlow` app target, not the
`ShiftFlowDomain` package. As placed in the app-hosted `ShiftFlowTests` target,
the domain symbols resolve via `@testable import ShiftFlowDomain`, but the
app-layer symbols will NOT resolve unless each of those four files also does
`@testable import ShiftFlow`.

Per TASK-XCODE-PROJECT-001 rules, tests must NOT be rewritten to pass and the
architecture must NOT be silently changed, so this is reported rather than
force-fixed. On macOS, choose ONE of:

1. Add `@testable import ShiftFlow` to the four affected test files (smallest change;
   a test-only import addition, no test logic changed), OR
2. Move the four ViewModels into the `ShiftFlowDomain` package (larger; changes the
   module boundary — requires Tech Lead approval).

Option 1 is recommended and is a configuration-scoped fix; it needs explicit
approval because it edits test files. Until resolved, the `ShiftFlowTests`
target will fail to compile the four affected files on macOS.

#### RESOLUTION (TASK-XCODE-FIX-001, v0.9.3)

XP-01 is resolved using Option 1 (configuration-scoped, no test logic changed):

- Added `@testable import ShiftFlow` (alongside the existing
  `@testable import ShiftFlowDomain`) to the four affected files so the app-layer
  ViewModels resolve when compiled by the app-hosted `ShiftFlowTests` Xcode target.
- Excluded those same four files from the standalone SPM `ShiftFlowDomainTests`
  target in `ShiftFlowDomain/Package.swift` (they cannot resolve the `ShiftFlow`
  app module under `swift build`). They are still compiled by the Xcode
  `ShiftFlowTests` target, which links both the app (`TEST_HOST` + testability)
  and the `ShiftFlowDomain` package.
- No application/domain source was moved; the module boundary is unchanged
  (ShiftFlowDomain has no dependency on the app; no circular dependency).
- No tests were deleted, disabled, weakened, or mocked.

Result: `swift build`/SPM compiles the pure-domain test subset; the Xcode
`ShiftFlowTests` target compiles the full suite including the four ViewModel tests.
Build/test execution remains PENDING macOS/Xcode.

### macOS build/verification commands

```bash
xcodebuild -list -project ShiftFlow.xcodeproj
xcodebuild -scheme ShiftFlow -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -scheme ShiftFlow -destination 'platform=iOS Simulator,name=iPhone 15' test
```
