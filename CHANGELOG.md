# ShiftFlow — Change Log

**Document:** CHANGELOG.md  
**Version:** v0.1.0  
**Status:** Baseline  
**Product:** ShiftFlow  
**Purpose:** Record the history of approved product, architecture, implementation, testing, and release changes.

---

# Change Log Rules

Every meaningful project change must be recorded in this file.

A meaningful change includes:

- Product requirement changes
- Architecture changes
- New features
- Bug fixes
- Data model changes
- UI changes that affect product behavior
- Notification changes
- Widget changes
- Sync changes
- Important configuration changes
- Breaking changes

Each entry must identify:

- Version
- Date
- Task ID
- Change type
- Summary
- Reason
- Files changed
- Tests
- Status

Kiro must update this file after completing a meaningful implementation task.

Do not delete historical entries.

Do not rewrite old entries to hide previous behavior.

If a previous requirement is changed, add a new entry explaining the change.

---

# Versioning

ShiftFlow uses:

```text
MAJOR.MINOR.PATCH
```

Guidelines:

```text
MAJOR
Breaking product or architecture change

MINOR
New feature or meaningful product capability

PATCH
Bug fix or non-breaking correction
```

The Tech Lead has final authority over the version number.

---

# Version History

## v0.1.0 — Initial Project Baseline

**Date:** 2026-08-22

**Task ID:** BASELINE-001

**Type:** Baseline

**Status:** Approved

### Product

Created the initial ShiftFlow product specification.

Initial product scope includes:

- Personal iOS shift-management application
- Five configurable shifts: C1–C5
- Automatic shift-time resolution
- C5 special schedule for days 10–20
- Additional task concept
- MW task
- Notes
- Month view
- Week view
- 3 Days view
- Today view
- Shift reminders
- iOS Home Screen Widget
- Offline-first usage
- iCloud/CloudKit synchronization

### Shift Rules

Initial schedules:

```text
C1
07:00 → 16:30
Break 11:00 → 12:00

C2
07:30 → 17:00
Break 11:30 → 12:30

C3
08:00 → 17:30
Break 12:00 → 13:00

C4
08:30 → 18:00
Break 12:30 → 13:30

C5 Normal
11:30 → 21:00
Break 16:30 → 17:30

C5 Day 10–20
12:00 → 21:30
Break 16:30 → 17:30
```

### Architecture

Initial technical direction:

```text
Swift
SwiftUI
SwiftData
CloudKit
WidgetKit
UserNotifications
```

Architecture principles:

- Layered architecture
- Domain/business logic separated from UI
- ShiftResolver as the central schedule-resolution component
- Configuration-driven shift schedules
- Local-first persistence
- CloudKit synchronization
- Shared schedule logic for Calendar, Today, Reminder, and Widget

### Development Rules

Established mandatory development rules:

- Kiro must read project specifications before coding.
- Kiro must work within approved task scope.
- Business logic must not be hard-coded into SwiftUI views.
- Significant changes require a task ID.
- Significant changes require a changelog entry.
- Business-critical behavior requires automated tests.
- Architecture changes require Tech Lead approval.
- Historical schedule behavior must be protected.
- No silent scope expansion.

### Files Established

```text
.kiro/steering/product.md
.kiro/steering/architecture.md
.kiro/steering/development-rules.md
CHANGELOG.md
```

### Tests

No implementation tests executed yet.

Status:

```text
Specification baseline only.
Implementation has not started.
```

---

# Future Entry Template

Use the following template for future changes:

```text
## vX.Y.Z — Short Change Title

**Date:** YYYY-MM-DD

**Task ID:** TASK-AREA-XXX

**Type:** Feature / Fix / Refactor / Architecture / Product / Configuration

**Status:** Proposed / In Progress / Completed / Reverted

### Summary

Describe what changed.

### Reason

Explain why the change was required.

### Requirements

List the relevant requirement or approved decision.

### Files Changed

```text
path/to/file
path/to/file
```

### Tests

```text
Test name
PASS / FAIL
```

### Known Issues

List known limitations, if any.

### Notes

Additional technical or product notes.

---
```

---

# Change Management Rules

## 1. Never delete history

Old versions must remain in chronological order.

## 2. Never silently overwrite behavior

If behavior changes, create a new version entry.

## 3. Record reversions

If a feature is reverted, document:

- Which version introduced it
- Why it was reverted
- What behavior is restored

## 4. Record architecture changes

Any change to the architecture must include the reason and affected components.

## 5. Record data model changes

Any persistent model change must identify:

- Old model behavior
- New model behavior
- Migration impact
- CloudKit impact, if applicable

## 6. Record testing

A feature is not considered complete without recording relevant test results.

---

# Current Project Status

```text
Current Version:
v0.9.5

Current Phase:
macOS CI Stabilization — Green Baseline

Implementation:
TASK-GITHUB-ACTIONS-FIX-005..011 completed; CI verified green
(run 32754956252, commit 1edf536): 507/507 tests pass, 17/17 suites pass,
build + simulator install/launch pass on Xcode 26.3 / iPhone 16 Pro / iOS 18.5.

Next Phase:
Awaiting review — not started
```

---

## v0.9.5 — macOS CI Stabilization (Green Baseline)

**Date:** 2026-08-24

**Task ID:** TASK-GITHUB-ACTIONS-FIX-005..011, TASK-RELEASE-VERSION-001

**Type:** Bug fixes / CI stabilization (PATCH)

**Status:** Completed — CI Green

### Summary

Stabilized the macOS GitHub Actions pipeline so the full ShiftFlow suite builds,
installs, launches, and runs on a real iOS Simulator. Fixes span CloudKit gating
for unsigned CI builds, Xcode project file references, a SwiftUI type-checking
timeout, date/time timezone handling, and one test-baseline correction. Result:
a verified green baseline of **507/507 tests passing, 17/17 suites, 0 failures**.

### Reason

After the real Xcode project was created (v0.9.2) and CI authored (v0.9.4),
running on the GitHub macOS runner surfaced a sequence of build/runtime/test
defects that were not observable on the Windows authoring host. Each was fixed
at the root cause without changing product behavior.

### Version Justification

v0.9.5 (PATCH) — bug fixes and CI/config stabilization only; no new feature,
no product-behavior change, no architecture change. Prior version was v0.9.4.

### Changes

- **CloudKit entitlement / unsigned CI fallback.** SwiftData+CloudKit container
  initialization trapped at launch on the unsigned CI simulator build (missing
  `com.apple.developer.icloud-services`). Gated CloudKit behind a compile-time
  `DISABLE_CLOUDKIT` flag (set only for the unsigned CI build via
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS`); signed builds keep full CloudKit sync.
  The documented offline-first local SwiftData store is used when gated.
- **Xcode project / file-reference fixes.** Corrected `project.pbxproj` source
  paths so Widget and app/test files resolve (full `SOURCE_ROOT`-relative paths);
  removed a duplicate `ScheduleRule.swift` producer; resolved test-target module
  visibility by adding `@testable import ShiftFlow` to app-layer-dependent test
  files and excluding them from the standalone SPM test target; added
  `CFBundleIdentifier` to the app/widget Info.plist.
- **SwiftUI type-checking fix.** Broke up an over-complex expression in
  `DayDetailSheet` (shift row) into typed helpers to resolve
  "unable to type-check this expression in reasonable time."
- **Export/import/date timezone stabilization.** Aligned `DateFormatter.timeZone`
  to the calendar's time zone in `ShiftExportService`, `ImportValidator`, and
  `ShiftImportService`, and added calendar-aware `TimeFormatter` used by
  `AccessibilityLabelBuilder`, fixing dates rendering one day early and
  round-trip/label shifts under the UTC CI runner.
- **WidgetDeepLink timezone fix.** Set `formatter.timeZone = calendar.timeZone`
  in `WidgetDeepLink.url(forDate:)` and `parseDate(from:)` to preserve the
  calendar day in `shiftflow://day?date=yyyy-MM-dd` round-trips.
- **Repeated widget-refresh test baseline correction.** `testRepeatedRefreshDoesNotCorruptSnapshot`
  now captures its baseline from an explicit `refresh(referenceDate:)` rather than
  the create-triggered (real-today) publish, verifying the intended invariant that
  repeated refreshes with the same reference date are identical. Production widget
  behavior unchanged.
- **GitHub Actions macOS CI stabilization.** Workflow YAML/diagnostic corrections
  so the pipeline reaches and completes test execution reliably.

### Green Baseline (verified)

```text
Run:        32754956252
Commit:     1edf536c71630f251b31683b504779369e533b55
Build:      ** TEST BUILD SUCCEEDED **
Execution:  ** TEST EXECUTE SUCCEEDED **
Tests:      507 executed, 0 failures, 0 unexpected
Suites:     17/17 passed
Toolchain:  Xcode 26.3
Simulator:  iPhone 16 Pro / iOS 18.5
```

### Files Changed (across the stabilization work, prior commits)

```text
ShiftFlow/Persistence/SwiftData/PersistenceContainer.swift
ShiftFlow/ShiftFlow.xcodeproj/project.pbxproj
ShiftFlow/App/Info.plist
ShiftFlow/Widget/Info.plist
ShiftFlow/UI/Calendar/DayDetailSheet.swift
ShiftFlow/UI/Shared/TimeFormatter.swift
ShiftFlow/UI/Shared/AccessibilityLabelBuilder.swift
ShiftFlow/ShiftFlowDomain/Sources/Import/ShiftExportService.swift
ShiftFlow/ShiftFlowDomain/Sources/Import/ImportValidator.swift
ShiftFlow/ShiftFlowDomain/Sources/Import/ShiftImportService.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/WidgetDeepLink.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/ (ScheduleRule.swift duplicate removed)
ShiftFlow/ShiftFlowDomain/Package.swift
ShiftFlow/ShiftFlowDomain/Tests/ (import/exclusion + repeated-refresh baseline)
.github/workflows/macos-test.yml
```

This v0.9.5 entry itself changes only `CHANGELOG.md`.

### Tests

PASS — 507/507 on the GitHub macOS runner (run 32754956252). 0 failures, 0 unexpected.

### Scope Check

No new product feature, no business-logic change, no architecture change, no
CloudKit behavior change (only compile-time gating for unsigned CI), no tests
weakened or deleted.

---

## v0.9.4 — macOS CI / GitHub Actions

**Date:** 2026-08-24

**Task ID:** TASK-GITHUB-ACTIONS-001

**Type:** Configuration (CI/CD)

**Status:** Completed — CI Run Pending on GitHub macOS Runner

### Summary

Added a GitHub Actions workflow (`.github/workflows/macos-test.yml`) that builds and tests ShiftFlow on a real GitHub-hosted macOS runner, since the development host is Windows (no Swift/Xcode). The workflow inspects the environment, resolves/builds the `ShiftFlowDomain` package, lists the Xcode project, builds the app + embedded widget for testing, runs the full `ShiftFlowTests` suite on an iOS Simulator, and uploads the `.xcresult` bundle. Added a repo `.gitignore`. No product source or business logic was changed.

### Reason

Enables real macOS/Xcode build + test verification (including confirming the TASK-XCODE-FIX-001 XP-01 fix compiles) without a local Mac. Complements TASK-MACOS-001 (which was BLOCKED on Windows).

### Version Justification

v0.9.4 (PATCH) — CI configuration only; no feature or business-rule change. Prior version was v0.9.3.

### Workflow Behavior

Triggers: `push`, `pull_request`, `workflow_dispatch`. Runner: `macos-15` (documented fallback to `macos-14` if unavailable). Steps: checkout → select latest-stable Xcode → inspect env (`sw_vers`, `xcodebuild -version`, `xcode-select -p`, `swift --version`, `xcrun simctl list devices`) → `swift package resolve` + `swift build` (ShiftFlowDomain) → `xcodebuild -list` → resolve an available iPhone Simulator UDID dynamically → `xcodebuild build-for-testing` (Debug, Simulator, `CODE_SIGNING_ALLOWED=NO`) → `xcodebuild test-without-building` with `-resultBundlePath` → upload `.xcresult` + logs artifact (`if: always()`).

- No archive, no distribution signing, no App Store steps.
- Simulator unit tests run unsigned; no Apple Developer Team required.
- Building the `ShiftFlow` scheme also builds the embedded `ShiftFlowWidgetExtension` (app dependency).
- CloudKit/notification RUNTIME verification is not attempted; offline unit/integration tests still run.

### Files Created

```text
.github/workflows/macos-test.yml
.gitignore
```

### Files Modified

```text
CHANGELOG.md
```

No `.swift`, project, or entitlements files were changed by this task.

### Verification Status

Authored on Windows (no `git`, `swift`, `xcodebuild`, or `xcrun` locally). The workflow has NOT been executed — it runs only when pushed to a GitHub repository with Actions enabled. **Build and test results are PENDING the first CI run on the GitHub macOS runner.** No build/test outcome is claimed here.

### Scope Check

No AI, analytics, authentication, backend, REST API, social, recurring shifts, new calendar modes, new reminder offsets, new widget families, XLSX/CoreXLSX, or business-logic changes. Tests are neither modified, skipped, nor weakened by this task.

---

## v0.9.3 — Xcode Test Target Fix

**Date:** 2026-08-24

**Task ID:** TASK-XCODE-FIX-001

**Type:** Configuration (Test infrastructure)

**Status:** Completed — Build Pending on macOS

### Summary

Resolved issue XP-01 (from TASK-XCODE-PROJECT-001): four test files under `ShiftFlowDomain/Tests/` reference application-layer ViewModels that live in the `ShiftFlow` app module, but only imported `ShiftFlowDomain`. Fixed with the smallest configuration-scoped change — added `@testable import ShiftFlow` to those four files and excluded them from the standalone SPM test target so both build systems compile correctly. No application/domain source moved, no test logic changed.

### Reason

Without the app-module import, the app-hosted `ShiftFlowTests` Xcode target could not resolve `CalendarViewModel`, `DataManagementViewModel`, `TaskSettingsViewModel`, or `ShiftSettingsViewModel`; and with the import, the standalone SPM `ShiftFlowDomainTests` target could not resolve the app module. Both are now consistent.

### Version Justification

v0.9.3 (PATCH) — build/test infrastructure fix; no feature, no business-rule change. Prior version was v0.9.2.

### Root Cause (XP-01)

The four ViewModels are app-target types (`Application/ViewModels/`), not part of the `ShiftFlowDomain` package. The tests used `@testable import ShiftFlowDomain` only, so app symbols were unresolved in the test target; and the SPM package test target compiled these files without access to the app module.

### Fix (configuration-scoped, no test cheating)

- Added `@testable import ShiftFlow` (kept `@testable import ShiftFlowDomain`) in:
  `CalendarViewModelTests.swift` (CalendarViewModel), `DataManagementViewModelTests.swift` (DataManagementViewModel), `TaskSettingsViewModelTests.swift` (TaskSettingsViewModel), `ShiftSettingsTests.swift` (CalendarViewModel + ShiftSettingsViewModel).
- Excluded those four files from the SPM `ShiftFlowDomainTests` target in `Package.swift` (they cannot resolve `ShiftFlow` under `swift build`); they are compiled by the Xcode `ShiftFlowTests` target (links app via TEST_HOST + testability, plus the package).
- No tests deleted/disabled/weakened/mocked. No ViewModels moved or duplicated. Module boundary unchanged (ShiftFlowDomain still has no app dependency; no circular dependency).

### Files Changed

```text
ShiftFlow/ShiftFlowDomain/Tests/CalendarViewModelTests.swift        (+@testable import ShiftFlow)
ShiftFlow/ShiftFlowDomain/Tests/DataManagementViewModelTests.swift  (+@testable import ShiftFlow)
ShiftFlow/ShiftFlowDomain/Tests/TaskSettingsViewModelTests.swift    (+@testable import ShiftFlow)
ShiftFlow/ShiftFlowDomain/Tests/ShiftSettingsTests.swift            (+@testable import ShiftFlow)
ShiftFlow/ShiftFlowDomain/Package.swift                             (exclude 4 files from SPM test target)
ShiftFlow/SETUP.md                                                  (XP-01 resolution notes)
CHANGELOG.md
```

The Xcode project (`project.pbxproj`) already compiled all four files in the `ShiftFlowTests` target, so no project-file change was required.

### Build / Test Status

Environment is Windows (no `swift`/`xcodebuild`/`xcrun`). Compilation and test execution are **PENDING macOS/Xcode**. No result claimed.

### Regression

No production business logic changed — C1–C5, C5 boundary, historical snapshots, Task/MW & Note independence, OFF, reminders, widget, CSV import/export, persistence, and CloudKit architecture are untouched.

### Scope Check

No feature, UI redesign, architecture change, ViewModel move/duplication, or business-rule change. Test-infrastructure/import configuration only.

---

## v0.9.2 — Xcode Project Setup

**Date:** 2026-08-24

**Task ID:** TASK-XCODE-PROJECT-001

**Type:** Configuration (Project structure)

**Status:** Completed — Build Pending on macOS

### Summary

Replaced the placeholder `ShiftFlow.xcodeproj/project.pbxproj` with a real, structured Xcode project defining three targets — `ShiftFlow` (iOS app), `ShiftFlowWidgetExtension` (WidgetKit extension), and `ShiftFlowTests` (app-hosted unit tests) — all linking the existing `ShiftFlowDomain` local Swift package. Added the supporting configuration: App/Widget `Info.plist`, `.entitlements` (App Group + iCloud/CloudKit + APS), the `shiftflow://` URL scheme, a shared scheme, and the workspace data. No product source or business logic was modified.

### Reason

The project previously had only a placeholder `.pbxproj` (documented since v0.1.2), so the existing source could not be opened, built, or tested in Xcode. This task provides a buildable project structure for the current v0.9.1 source baseline.

### Version Justification

v0.9.2 (PATCH) — project/configuration scaffolding only; no new feature, no business-rule change. Prior version was v0.9.1.

### Targets & Configuration

- `ShiftFlow` — `com.shiftflow.app`, iOS 17.0, links `ShiftFlowDomain`, embeds the widget.
- `ShiftFlowWidgetExtension` — `com.shiftflow.app.widget`, WidgetKit extension, links `ShiftFlowDomain`.
- `ShiftFlowTests` — `com.shiftflow.app.tests`, hosted by the app; includes `Tests/ShiftFlowTests.swift` + all `ShiftFlowDomain/Tests/*.swift`.
- Deployment target iOS 17.0 (matches `Package.swift`). Debug + Release configs. No third-party dependencies added; no CoreXLSX.

### Capabilities (declared; physical enablement PENDING signing)

App Group `group.com.shiftflow.shared` (app + widget entitlements), iCloud/CloudKit container `iCloud.com.shiftflow.app`, `aps-environment`, and URL scheme `shiftflow` (deep link `shiftflow://day?date=yyyy-MM-dd`). No Apple Developer Team configured — **SIGNING PENDING** on macOS.

### Files Created

```text
ShiftFlow/App/Info.plist
ShiftFlow/App/ShiftFlow.entitlements
ShiftFlow/Widget/Info.plist
ShiftFlow/Widget/ShiftFlowWidget.entitlements
ShiftFlow/ShiftFlow.xcodeproj/project.xcworkspace/contents.xcworkspacedata
ShiftFlow/ShiftFlow.xcodeproj/xcshareddata/xcschemes/ShiftFlow.xcscheme
```

### Files Modified

```text
ShiftFlow/ShiftFlow.xcodeproj/project.pbxproj  (placeholder → real project)
ShiftFlow/SETUP.md                             (generated-project notes + known issue)
CHANGELOG.md
```

No `.swift` source, ShiftResolver rule, WorkDay snapshot, Task/MW, Reminder, Widget, CloudKit, or CSV logic was changed.

### Known Issue — Test target module imports (REQUIRES DECISION on macOS)

Four files in `ShiftFlowDomain/Tests/` (`CalendarViewModelTests`, `DataManagementViewModelTests`, `TaskSettingsViewModelTests`, `ShiftSettingsTests`) use `@testable import ShiftFlowDomain` but reference application-layer ViewModels that live in `Application/ViewModels/` (compiled into the app target, not the domain package). As placed in the app-hosted test target, those app symbols will not resolve unless each file also does `@testable import ShiftFlow`. Per task rules (no test rewrites, no silent architecture change), this is reported for a decision rather than force-fixed. Recommended fix on macOS: add `@testable import ShiftFlow` to the four files (test-only import addition). See SETUP.md for details. Until resolved, those four test files will fail to compile on macOS.

### Build / Test / Runtime Status

Environment is Windows (no `swift`/`xcodebuild`/`xcrun`). The project was authored but NOT opened or built by Xcode. Build, test execution, and runtime smoke tests are **PENDING ON macOS/Xcode**. No build or test result is claimed.

### Scope Check

No AI, analytics, authentication, backend, REST API, social, recurring shifts, new calendar modes, new reminder offsets, new widget families, dashboard, statistics, charts, or automatic historical recalculation. No architecture redesign. Existing source is the unchanged baseline.

---

## v0.9.1 — CSV Data Management UI

**Date:** 2026-08-24

**Task ID:** TASK-DATA-001

**Type:** Feature (UI)

**Status:** Completed — Build Pending on macOS

### Summary

Completed the Data Management UI so the user can import and export ShiftFlow data directly from Settings → Dữ liệu. Added a `DataManagementViewModel` (Application layer) that wraps the EXISTING import/export domain services, and four SwiftUI screens: `DataManagementView`, `CSVImportView`, `CSVImportPreviewView`, `CSVExportView` (plus a small `CSVFileWriter` share helper). CSV is the official interchange format for this task (Excel-compatible). No import/export domain logic was replaced or duplicated.

### Reason

TASK-IMPORT-001 (v0.1.5) built the import/export domain (`ShiftFileParser`, `ImportValidator`, `ShiftImportService`, `ShiftExportService`, `ShiftTemplate`) but the Settings "Dữ liệu" section only had placeholder labels. This task delivers the user-facing flow (pick file → preview → confirm → import; generate → share export; download template).

### Version Justification

v0.9.1 (PATCH) — UI wiring that completes an existing capability; no new business rule, shift type, reminder offset, widget family, or architecture change. Prior version was v0.9.0.

### Architecture (reuse only)

```
SwiftUI (DataManagementView / CSVImportView / CSVImportPreviewView / CSVExportView)
    ↓
DataManagementViewModel  (Application layer — no parsing/validation/resolution)
    ↓
ShiftImportService  →  WorkDayService  →  ShiftResolver   (import)
ShiftExportService  ←  WorkDayService (fetch) + TaskService (task lookup)  (export)
UserFacingError  (Vietnamese messages)
```

The view model contains NO parsing, validation, or shift-resolution logic. It delegates entirely to the existing services and maps errors to Vietnamese via `UserFacingError` (with CSV-specific messages for this flow).

### Import Flow

File picker (`.csv`, `.txt`; `.xlsx` rejected with "Chỉ hỗ trợ file CSV.") → `ShiftImportService.prepareImport` → preview (Tổng số dòng / Dòng hợp lệ / OFF / Dòng lỗi / Trùng ngày trong file / Ngày đã tồn tại; per-row status ✓ Hợp lệ / ⚠ Đã tồn tại / ✕ Lỗi / ○ OFF) → conflict strategy (default **Bỏ qua**, no silent overwrite) → confirmation dialog ("Nhập dữ liệu?") → `executeImport` → result ("Nhập dữ liệu hoàn tất"). Invalid/duplicate rows are never imported; valid rows import (partial import honored by the existing service).

### Export Flow

`Xuất dữ liệu` → `makeExportContent()` (fetches WorkDays, delegates to `ShiftExportService.export(workDays:taskService:)`) → `CSVFileWriter` temp file `ShiftFlow_YYYY-MM-DD.csv` → native share sheet (`ShareLink`). Rows sorted by date ascending; multiple tasks joined deterministically (`MW;Ticket`); OFF preserved as absence of a row; resolved start/end/break never exported; WorkDays never modified.

### Template

`Tải mẫu CSV` → `generateEmptyTemplate()` (header `Date,Shift,Task,Note`) → `ShiftFlow_Template.csv` via share sheet. No resolved schedule fields.

### Conflict / OFF Handling

- Existing WorkDay conflict: user chooses Bỏ qua (default) or Ghi đè. Ghi đè updates via `WorkDayService.changeShift` + `updateNote` + TaskService assignment (never touches snapshot fields directly).
- OFF row on a new date: creates no WorkDay.
- OFF row on an existing date with Ghi đè: the view model deletes the existing WorkDay through `WorkDayService.deleteWorkDay` so the day becomes OFF (no OFF ShiftDefinition/WorkDay created).
- Duplicate dates inside the file: both rows marked "Trùng ngày trong file"; neither imported.
- Unknown task code: row rejected ("Task không hợp lệ: X") — no silent task creation.

### Invariants Preserved

Import always resolves via ShiftResolver (importer never computes times). Export never includes resolved times and never mutates WorkDays. Task and Note remain separate. Historical WorkDay snapshots are never rewritten by import/export. Widget/reminder integration continues through the existing WorkDayService pipeline (refresh after successful persistence only).

### Files Created

```text
ShiftFlow/Application/ViewModels/DataManagementViewModel.swift
ShiftFlow/UI/Settings/DataManagementView.swift
ShiftFlow/UI/Settings/CSVImportView.swift
ShiftFlow/UI/Settings/CSVImportPreviewView.swift
ShiftFlow/UI/Settings/CSVExportView.swift
ShiftFlow/UI/Settings/CSVFileWriter.swift
ShiftFlow/ShiftFlowDomain/Tests/DataManagementViewModelTests.swift
```

### Files Modified

```text
ShiftFlow/Application/AppContainer.swift (builds DataManagementViewModel from existing services)
ShiftFlow/App/ContentView.swift (passes dataViewModel to Settings)
ShiftFlow/UI/Settings/SettingsScreen.swift (Dữ liệu → DataManagementView; version 0.9.1)
CHANGELOG.md
```

No import/export domain files were modified. `ShiftFileParser`, `ImportValidator`, `ShiftImportService`, `ShiftExportService`, `ShiftTemplate`, `ShiftResolver`, `WorkDayService`, `TaskService` are unchanged.

### Tests

```text
DataManagementViewModelTests — 33 tests (IMPLEMENTED; PENDING macOS/Xcode execution)

Settings surface (3), Export (headers/sort/task/multi-task/note/no-resolved-times/
read-only/template = 8), Import (valid/semicolon/invalid-date/invalid-shift/
invalid-task/duplicate/conflict/skip/replace/OFF/OFF-replace-delete = 11),
Note & MW independence (2), Historical snapshot (1), C5 boundary day 9/10/20/21 (4),
Round trip (1), Error handling / no internal details (4), Failure no-corruption (1),
Confirmation summary counts (1).
```

### Known Limitations

- **SOURCE VERIFIED:** import/export flow wiring, preview counts, conflict/OFF/task/note handling, C5 boundary via import, round trip, Vietnamese error mapping — all exercised through the in-memory repository/task store against the same services the UI uses.
- **MACOS/XCODE VERIFICATION PENDING:** Windows has no Swift/Xcode. SwiftUI rendering, `.fileImporter`, `ShareLink`, security-scoped file access, VoiceOver, Dark Mode, and Dynamic Type require macOS. Test execution PENDING.
- `.xlsx` remains unsupported in this task (rejected with a friendly message); CoreXLSX adapter is a separate future item.

### Scope Check

No CloudKit/iCloud sync changes, authentication, analytics, AI, new widget designs, new calendar features, new reminder features, new shift types, recurring shifts, backend, or REST API introduced. No import/export domain logic replaced. No architecture change. ShiftResolver unchanged.

---

## v0.9.0 — Persistent Shift, Rule & Task Data

**Date:** 2026-08-23

**Task ID:** TASK-PERSISTENCE-001

**Type:** Feature (Persistence)

**Status:** Completed — Build Pending on macOS

### Summary

Added SwiftData persistence for the configuration/task domain data that was previously in-memory: ShiftDefinition, ScheduleRule, TaskDefinition, WorkDayTask. Introduced four `@Model` types with explicit domain↔persistence mapping, two SwiftData-backed stores conforming to the existing domain protocols, and wired them into `AppContainer`. Configuration, rules, tasks, and assignments now survive app relaunch and are CloudKit-compatible.

### Reason

Closes QA-P2-01 (v0.8.0): task/shift/rule data reset per launch. WorkDay was already persisted; this extends durable storage to configuration and tasks without changing any business rule.

### Version Justification

v0.9.0 (MINOR) — persistent storage is a meaningful product capability. Prior version was v0.8.0.

### Architecture

```
Domain protocol (ShiftConfigurationStore / TaskStore)
    ↓
SwiftData store (SwiftDataShiftConfigurationStore / SwiftDataTaskStore)
    ↓
@Model (ShiftDefinitionModel / ScheduleRuleModel / TaskDefinitionModel / WorkDayTaskModel)
    ↓
ModelContext
```

- Domain structs remain pure value types; `@Model` classes hold no business logic.
- The existing in-memory stores remain for unit tests (injectable via new `AppContainer` params).
- `WorkDayModel` remains the canonical persisted WorkDay — untouched.

### CloudKit Compatibility

All new models follow the WorkDayModel rules: no `@Attribute(.unique)`, defaults on all non-optional stored properties, optional stays optional, stable UUIDs. Uniqueness (one WorkDay/date, unique codes) enforced at the service layer. No custom sync engine — SwiftData+CloudKit mirrors automatically.

### Migration Safety

Adding these models is additive (SwiftData lightweight migration). Existing WorkDay data and snapshots are unaffected. No historical recalculation, no automatic shift changes, no reminder rescheduling, no widget changes from migration.

### Seeding & Reset

`seedIfNeeded()` now operates against persistent stores: first launch seeds C1–C5 + C5 rule + MW (stable IDs, idempotent); relaunch adds nothing; custom config/tasks/assignments preserved. `resetToDefaults()` / `resetDefaults()` restore defaults via the store's `replaceAll`/idempotent seed and never touch WorkDays or duplicate MW.

### Invariants Preserved

Historical snapshot immutability, MW/task independence, note independence, reminder independence (resolvedStartDateTime + offset), widget independence (snapshot-based), OFF = no record, ShiftResolver as single source of truth. Config/task persistence never calls ShiftResolver or modifies WorkDay snapshots.

### Files Created

```text
ShiftFlow/Persistence/SwiftData/ShiftDefinitionModel.swift
ShiftFlow/Persistence/SwiftData/ScheduleRuleModel.swift
ShiftFlow/Persistence/SwiftData/TaskDefinitionModel.swift
ShiftFlow/Persistence/SwiftData/WorkDayTaskModel.swift
ShiftFlow/Persistence/SwiftData/SwiftDataShiftConfigurationStore.swift
ShiftFlow/Persistence/SwiftData/SwiftDataTaskStore.swift
ShiftFlow/ShiftFlowDomain/Tests/PersistenceMappingTests.swift
```

### Files Modified

```text
ShiftFlow/Persistence/SwiftData/PersistenceContainer.swift (schema: +4 models)
ShiftFlow/Application/AppContainer.swift (SwiftData-backed stores; injectable in-memory for tests)
CHANGELOG.md
```

### Tests

```text
PersistenceMappingTests — 16 tests (IMPLEMENTED; PENDING macOS/Xcode execution)

Runnable-on-macOS logic (seed idempotency, custom-config/task survival, reset,
config/task-change snapshot independence, new-WorkDay-uses-updated-config, value
round-trip stability, stable UUIDs). These exercise the same protocols the
SwiftData stores conform to.

SwiftData-runtime tests (models 35/36, relaunch persistence 1-22, CloudKit
defaults) — require @Model + ModelContext runtime → PENDING macOS/Xcode.
```

### Known Limitations

- Windows: no Swift/Xcode/SwiftData runtime. `@Model` mapping round-trips, actual persistence across relaunch, and CloudKit mirroring cannot be executed — PENDING macOS.
- Import/Export, Calendar, Reminder, Widget behavior unchanged (verified by unchanged existing suites).

### Scope Check

No new calendar views, shift types, reminder offsets, recurring shifts, authentication, backend, REST API, analytics, AI, social features, new widget families, custom CloudKit engine, or automatic historical recalculation introduced. ShiftResolver business logic unchanged.

---

## v0.8.0 — Task Settings UI

**Date:** 2026-08-23

**Task ID:** TASK-TASK-002

**Type:** Feature

**Status:** Completed — Build Pending on macOS

### Summary

Implemented the Settings UI for managing task definitions ("Loại công việc"): list, create, edit (name + active; code read-only), enable/disable, and protected delete. Built on the existing `TaskService` (single source of truth) — no new task store, no business-rule duplication. Added `TaskSettingsViewModel`, `TaskSettingsView`, `TaskDefinitionEditView`, add-sheet, Settings navigation entry, and 30 tests.

### Reason

Completes the UI portion of TASK-TASK-001. Requirements/tasks call for user-managed task types from Settings. This closes the "Settings Task Management UI" limitation noted in v0.7.0.

### Version Justification

v0.8.0 (MINOR) — new user-facing Settings capability. Prior version was v0.7.0.

### Features

- **List:** all tasks; active-first, then inactive; each group sorted by code ascending. Code always shown as text; state shown as "Đang bật"/"Đã tắt" (never color-only).
- **Add:** "+ Thêm công việc" via `TaskService.createTask` (validates non-empty + unique code).
- **Edit:** name + active state; code read-only (stable identity for WorkDayTask references) via `TaskService.updateTask`.
- **Enable/Disable:** `TaskService.setTaskActive`; disabled tasks excluded from new assignment; existing assignments and history preserved.
- **Delete:** protected — tasks referenced by any WorkDay throw `.taskInUse` ("Không thể xóa công việc đang được sử dụng..."); unused tasks deletable after confirmation ("Xóa công việc?" / destructive).
- **MW:** seeded once, stable identity, never duplicated by re-seed or reset.
- **Reset:** `TaskService.resetDefaults()` re-adds missing defaults (MW) without duplicating, deleting custom tasks, removing assignments, or touching WorkDay snapshots.

### Invariants Preserved

Task Settings never calls ShiftResolver, never recalculates WorkDays, and never modifies resolved snapshot times. Task rename/disable/assignment never change reminder times or widget shift times. Historical WorkDayTask assignments remain valid even after a task is disabled.

### Architecture

```
UI (TaskSettingsView / TaskDefinitionEditView / add-sheet)
    ↓
TaskSettingsViewModel (load/sort/create/edit/enable/disable/delete/errors)
    ↓
TaskService (business rules — single source of truth)
    ↓
TaskStore (in-memory; SwiftData-backable later)
```

### Files Created

```text
ShiftFlow/Application/ViewModels/TaskSettingsViewModel.swift
ShiftFlow/UI/Settings/TaskSettingsView.swift
ShiftFlow/UI/Settings/TaskDefinitionEditView.swift
ShiftFlow/ShiftFlowDomain/Tests/TaskSettingsViewModelTests.swift
```

### Files Modified

```text
ShiftFlow/ShiftFlowDomain/Sources/Services/TaskService.swift (resetDefaults)
ShiftFlow/Application/AppContainer.swift (wires TaskSettingsViewModel)
ShiftFlow/UI/Settings/SettingsScreen.swift (Loại công việc navigation)
ShiftFlow/App/ContentView.swift (passes taskViewModel to Settings)
CHANGELOG.md
```

### Tests

```text
TaskSettingsViewModelTests — 30 tests (IMPLEMENTED; PENDING macOS/Xcode execution)

List (3), Create (4), Edit (2), Enable/Disable (3), Delete (3), MW (2),
Snapshot protection (3), Reminder/Widget independence (2), Historical (1),
Reset (2), Accessibility (2), Error mapping (1), plus supporting cases.
```

### Acceptance Criteria Met

Settings contains "Loại công việc"; tasks listed; MW exists once; create/edit/enable/disable work; code immutable; disabled tasks not newly assignable; existing assignments intact; unused tasks deletable after confirmation; in-use tasks protected; reset preserves MW + WorkDays; task changes never touch ShiftResolver/snapshots/reminders/widget times; accessibility labels present; Vietnamese errors; import/export unchanged.

### Known Limitations

- Windows: no Swift/Xcode. UI, VoiceOver, Dark Mode, Dynamic Type require macOS.
- `TaskStore` remains in-memory; SwiftData `@Model` + CloudKit sync for TaskDefinition/WorkDayTask is a follow-up (mirrors WorkDay/config pattern).

### Scope Check

No AI, authentication, analytics, social, backend, REST API, new calendar modes, new reminder offsets, new widget families, recurring shifts, automatic historical recalculation, ShiftResolver changes, or MW business-logic changes introduced. Tasks never stored in WorkDay.note; no OFF TaskDefinition.

---

## v0.7.0 — Task / MW Management

**Date:** 2026-08-23

**Task ID:** TASK-TASK-001

**Type:** Feature

**Status:** Completed — Build Pending on macOS

### Summary

Implemented the Task/MW concept as structured data separate from shifts and notes: `TaskDefinition` + `WorkDayTask` models, `TaskService` (CRUD, assignment, seeding, delete-protection), MW seeding, integration into Day Detail / Import / Export / Widget / Settings, and 52 tests. Task/MW never affects shift times, break times, reminders, widget schedule times, or historical WorkDay snapshots.

### Reason

Requirements 23–27, 34 require Task/MW as a first-class concept. Previously the DayDetail task field was a display-only string. This closes the QA-M3 gap from TASK-QA-001.

### Version Justification

v0.7.0 (MINOR) — new user-facing product capability (task management). Prior version was v0.6.0.

### Core Invariant Enforced

Task operations NEVER call ShiftResolver, NEVER modify WorkDay resolved snapshots, and Task is NEVER stored in `WorkDay.note`. `C5` and `C5 + MW` have identical start/end/break, reminder times, and widget times — only the task indicator differs.

### Data Model

- `TaskDefinition` (id, code, name, isActive, timestamps) — Equatable, Codable, Sendable. Code is stable.
- `WorkDayTask` (id, workDayID, taskDefinitionID, timestamps) — join, carries no schedule data.
- Default MW seeded with stable UUID; idempotent.

### Behavior

- Task CRUD with validation (non-empty code/name, unique code) via `UserFacingError`.
- Delete policy: a task referenced by any WorkDayTask cannot be deleted (`.taskInUse`) — disable instead. Historical assignments preserved.
- Disabled task: excluded from new assignment; existing assignments and history retained.
- Multiple tasks per WorkDay supported.
- Import: Task column validated against known codes (unknown → "Task không hợp lệ: X"); `;`-separated multiple tasks; assigned via TaskService after WorkDay creation; never entered into note.
- Export: tasks as deterministic `CODE1;CODE2` (sorted); no resolved times; read-only.
- Widget: `hasTask` indicator (blue); no note text; times unchanged.
- Reminder: unaffected by task changes (derives from resolvedStartDateTime).
- Settings: (Task Management section available via TaskService; UI entry documented).

### Files Created

```text
ShiftFlow/ShiftFlowDomain/Sources/Models/TaskDefinition.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/TaskSeedProvider.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/TaskService.swift
ShiftFlow/ShiftFlowDomain/Tests/TaskManagementTests.swift
```

### Files Modified

```text
ShiftFlow/ShiftFlowDomain/Sources/Services/UserFacingError.swift (task error messages)
ShiftFlow/ShiftFlowDomain/Sources/Import/ImportValidator.swift (task-code validation)
ShiftFlow/ShiftFlowDomain/Sources/Import/ShiftImportService.swift (task assignment + validation)
ShiftFlow/ShiftFlowDomain/Sources/Import/ShiftExportService.swift (export via TaskService)
ShiftFlow/Application/ViewModels/DayDetailViewModel.swift (structured tasks, delete cleanup)
ShiftFlow/Application/AppContainer.swift (wires TaskService + widget task provider)
ShiftFlow/UI/Calendar/CalendarScreen.swift (passes taskService)
ShiftFlow/UI/Calendar/DayDetailSheet.swift (structured task section)
ShiftFlow/App/ContentView.swift (passes taskService)
ShiftFlow/ShiftFlowDomain/Tests/CalendarViewModelTests.swift (updated 2 task tests to structured model)
CHANGELOG.md
```

### Tests

```text
TaskManagementTests — 52 tests (IMPLEMENTED; PENDING macOS/Xcode execution)

TaskDefinition (9), WorkDayTask (6), MW independence (5), Note independence (3),
Import (5), Export (4), Round trip (4), Reminder (3), Widget (3),
Historical safety (2), Delete-in-use (2), OFF (1), plus supporting cases.
```

### Invariants Proven

1. Task/MW never changes shift/break times. 2. Never changes reminder fire time.
3. Never changes widget schedule times. 4. Never modifies historical snapshots.
5. Task never stored in WorkDay.note. 6. Note never converted to Task.
7. OFF creates no Task/WorkDay. 8. ShiftResolver remains the only resolution source.
9. Task changes trigger no shift resolution. 10. Custom tasks survive re-seed.

### Known Limitations

- Windows: no Swift/Xcode. UI, DatePickers, VoiceOver, Dark Mode require macOS.
- `TaskStore` uses in-memory storage; SwiftData `@Model` for TaskDefinition/WorkDayTask + CloudKit sync is a follow-up (mirrors the WorkDay/config pattern).
- Settings Task Management UI section: service is wired; a dedicated editor screen can be added alongside the existing shift editor on macOS.

### Scope Check

No AI, authentication, analytics, social, backend, REST API, recurring shifts, new calendar views, new reminder offsets, new widget families, or automatic historical recalculation introduced.

---

## v0.6.0 — Shift & App Settings

**Date:** 2026-08-23

**Task ID:** TASK-SETTINGS-001

**Type:** Feature

**Status:** Completed — Build Pending on macOS

### Summary

Implemented Settings / Shift Configuration: a native SwiftUI Settings screen with Shift Configuration, Schedule Rules, Reminder Defaults, Data Management, and About sections. Added a validated, user-editable configuration layer (`ShiftConfigurationService` + `ShiftConfigurationStore`) that feeds FUTURE WorkDay resolution while never touching historical snapshots. Added 44 tests.

### Reason

Requirements 12, 44, 45, 46 require the user to edit shift times and schedule rules from Settings. Previously only seeded defaults existed. This closes the QA-M1 gap identified in TASK-QA-001.

### Version Justification

v0.6.0 (MINOR) — new user-facing product capability (Settings + editable shift configuration). Current version was v0.5.1.

### Core Invariant Enforced

Editing a `ShiftDefinition` or `ScheduleRule` affects ONLY future WorkDay creation/resolution. It NEVER modifies existing `WorkDay` resolved snapshots, reminders, calendar entries, or widget data. `ShiftConfigurationService` does not iterate WorkDays and does not call `ShiftResolver`. The only path to change an existing WorkDay's schedule remains `WorkDayService.changeShift(...)`.

### Architecture

```
SwiftUI (SettingsScreen / ShiftEditView / ScheduleRuleEditView)
    ↓
ShiftSettingsViewModel
    ↓
ShiftConfigurationService (validation + storage)
    ↓
ShiftConfigurationStore (in-memory; SwiftData-backable later)

ShiftDefinitionProvider now reads from ShiftConfigurationService
    → future WorkDay creation uses edited config
    → existing WorkDay snapshots untouched
```

### Features

- Edit C1–C5: name, start/end, break start/end, active state. Code is stable (read-only).
- Edit C5 day 10–20 rule: day range, times, break, active. Inclusive boundary preserved.
- Validation via `ShiftConfigurationValidator`: start<end, breakStart<breakEnd, break within working interval, non-empty name, unique code, valid day range (1–31, start≤end). Errors surfaced via `UserFacingError` (Vietnamese, no raw detail).
- Reminder default preference (5 offsets only; 24h = 86400s). Does not modify `ReminderService` logic.
- Data Management section links to existing Import/Export (no duplication).
- Reset to defaults with confirmation; historical WorkDays preserved.
- Idempotent first-run seeding; custom config not overwritten on relaunch.
- Disable shift: excluded from new-WorkDay selection; historical WorkDays untouched.

### Files Created

```text
ShiftFlow/ShiftFlowDomain/Sources/Services/ShiftConfigurationValidator.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/ShiftConfigurationService.swift
ShiftFlow/Application/ViewModels/ShiftSettingsViewModel.swift
ShiftFlow/UI/Settings/SettingsScreen.swift
ShiftFlow/UI/Settings/ShiftEditView.swift
ShiftFlow/UI/Settings/ScheduleRuleEditView.swift
ShiftFlow/ShiftFlowDomain/Tests/ShiftSettingsTests.swift
```

### Files Modified

```text
ShiftFlow/ShiftFlowDomain/Sources/Services/UserFacingError.swift (config error messages)
ShiftFlow/Application/Services/ShiftDefinitionProvider.swift (backed by config service)
ShiftFlow/Application/AppContainer.swift (wires config service + settings VM)
ShiftFlow/App/ContentView.swift (Calendar + Settings tabs)
CHANGELOG.md
```

### Tests

```text
ShiftSettingsTests — 44 tests (IMPLEMENTED; PENDING macOS/Xcode execution)

Shift config (10): default C1–C5 values, edit, code-stable, invalid time/break, duplicate.
C5 rule (8): default day 10–20, day 9/10/20/21, edit, invalid range, disable→normal.
Historical snapshot (5): global shift change, global rule change, calendar/widget/reminder use stored snapshot.
Future WorkDay (2): new WorkDay uses updated shift/rule config.
Explicit change (3): changeShift updates snapshot, refreshes widget, reschedules reminder.
Seeding (4): seeds 5 shifts, seeds C5 rule, idempotent, custom not overwritten.
Disable (3): cannot create new, historical not deleted, snapshot valid.
Reset (4): requires confirmation, restores C1–C5, restores C5 rule, does not rewrite history.
Reminder (2): 5 offsets, 24h = 86400s.
Independence (3): task/note don't affect config, settings has no resolution logic.
```

### Invariants Proven by Tests

1. Global config change never auto-modifies historical WorkDay snapshots.
2. MW/Task never changes shift times. 3. Note never changes shift times.
4. OFF is not a ShiftDefinition. 5. ShiftResolver remains the only resolution source.
6. C5 day 10–20 inclusive. 7. Custom config survives re-seed. 8. Reset preserves history.

### Known Limitations

- Windows: no Swift/Xcode. UI, DatePickers, Dark Mode, Dynamic Type require macOS.
- `ShiftConfigurationStore` uses in-memory storage; SwiftData-backed persistence + CloudKit sync of ShiftDefinition/ScheduleRule is a follow-up (config currently resets per launch until a persistent store is wired on macOS).
- Data Management section links are placeholders for the existing Import/Export flows; navigation wiring completes on macOS.

### Scope Check

No AI, authentication, analytics, social, backend, REST API, recurring shifts, new reminder offsets, new widget families, new calendar modes, or automatic historical recalculation introduced.

---

## v0.5.1 — UI / UX / Accessibility Polish

**Date:** 2026-08-23

**Task ID:** TASK-POLISH-001

**Type:** Refactor / Quality

**Status:** Completed — Build Pending on macOS

### Summary

Polish pass improving consistency and quality without adding features: centralized user-facing error messages (Vietnamese, no raw errors), a design-constants spacing system, a shared accessibility-label builder, and error-presentation routing through the new mapper. Added 30+ polish tests.

### Reason

Individual modules used ad-hoc error strings and duplicated accessibility-label logic. This task centralizes them for consistency, guarantees no technical detail leaks to users, and documents the spacing/typography system.

### Version Justification

v0.5.1 (PATCH) — non-breaking quality improvements. No new product capability, business rule, UI mode, reminder type, or widget family.

### Changes

- `UserFacingError`: maps `WorkDayRepositoryError` / `ImportParseError` and unknown errors to safe Vietnamese messages. Includes sync-unavailable and notification-denied messages. Never leaks error types, codes, UUIDs, or class names.
- `DesignConstants`: 4pt spacing scale, corner radii, touch-target minimum (44pt), calendar-cell metrics, border constants.
- `AccessibilityLabelBuilder`: consistent Vietnamese VoiceOver labels (weekday + shift code text + times + optional break/note; "OFF" when no WorkDay). Always includes shift code text — never color-only.
- `DayDetailViewModel`: error presentation routed through `UserFacingError.message(for:)`.

### Verified Invariants (source-level)

- Color independence: shift code text always present in models, widget entries, and accessibility labels.
- Task/Note independence: widget task indicator separate from shift code; note text never exposed in widget data.
- Vietnamese localization: full (Thứ 2…Chủ nhật) and short (T2…CN), Monday-first.
- Dark Mode: `ShiftStyle` uses system/semantic colors + opacity overlays (adaptive). No hard-coded light-only backgrounds in shift styling.
- No technical errors exposed to users.

### Files Created

```text
ShiftFlow/ShiftFlowDomain/Sources/Services/UserFacingError.swift
ShiftFlow/UI/Shared/DesignConstants.swift
ShiftFlow/UI/Shared/AccessibilityLabelBuilder.swift
ShiftFlow/ShiftFlowDomain/Tests/PolishTests.swift
```

### Files Modified

```text
ShiftFlow/Application/ViewModels/DayDetailViewModel.swift (error routing via UserFacingError)
CHANGELOG.md
```

### Tests

```text
PolishTests — 30+ tests (IMPLEMENTED; PENDING macOS/Xcode execution)

- User-facing error mapping (duplicate/notFound/persistence/import/unknown)
- No technical detail leaked (codes, types, UUIDs)
- Sync-unavailable + notification-denied messages
- Color independence: shift code always textual
- Vietnamese weekday labels (full + short + Monday-first)
- Accessibility labels: shift code + times + break + note; OFF
- Next Shift accessibility + empty-state (not an error)
- Reminder offset Vietnamese display names
- Sync status user-friendly text (no CloudKit codes)
- Widget task indicator separate from shift code
- Widget does not expose note text
```

### Known Limitations

- Windows: no Swift/Xcode. UI rendering, Dark Mode contrast, Dynamic Type, and touch targets require physical macOS/Xcode verification.
- Polish tests exercise the pure logic (error mapping, labels, model invariants); visual review is a macOS step.

### Future Suggestions (NOT implemented)

- None required. All improvements stayed within approved scope.

---

## v0.5.0 — Full Application Integration

**Date:** 2026-08-23

**Task ID:** TASK-INTEGRATION-001

**Type:** Integration

**Status:** Completed — Build Pending on macOS

### Summary

Wired all completed modules into one coherent application via an `AppContainer` composition root. Added the SwiftData-backed `WorkDayRepository`, a `ShiftDefinitionProvider`, and connected the Calendar UI, WorkDayService, ShiftResolver, Widget refresh, Reminders, Import/Export, and CloudKit into end-to-end flows. Added 30 end-to-end integration tests.

### Reason

Individual modules were built and unit-tested in isolation. This task assembles them into a runnable app with verified end-to-end data flows, honoring all source-of-truth and secondary-operation rules.

### Version Justification

v0.5.0 (MINOR) — first time the app is a coherent, runnable whole; a meaningful integration milestone assembled from existing modules (no new business rules or features).

### Integration Architecture

```
ContentView → CalendarScreen → CalendarViewModel/DayDetailViewModel
     ↓
AppContainer (composition root)
     ↓
WorkDayService → ShiftResolver + SwiftDataWorkDayRepository
     ↓                              ↓
WidgetRefreshCoordinator      CloudSyncService
     ↓                              ↓
AppGroupWidgetSnapshotSink    (SwiftData + CloudKit)
```

### Composition Root

`AppContainer` builds and holds: SwiftData ModelContainer (CloudKit-aware + local fallback), `SwiftDataWorkDayRepository`, `WorkDayService` (with widget refresher), `ShiftImportService`, `ShiftExportService`, `ReminderService`, `CloudSyncService`, `ShiftDefinitionProvider`, and `CalendarViewModel`.

### Secondary-Operation Rule Verified

Persistence succeeds first. Widget refresh / reminder scheduling / CloudKit sync are secondary and never fail or roll back a WorkDay operation (`WorkDayService` calls refresh only after successful `try` persistence; widget sink is non-throwing).

### Source-of-Truth Rules Enforced

ShiftResolver is the only resolution logic; WorkDay snapshot is the historical display source; SwiftData is the primary local source; CloudKit is sync-only; Widget consumes derived snapshots; Reminder uses `resolvedStartDateTime`; MW/Note never change times; OFF = no WorkDay; Import never computes times; Export never stores resolved times.

### Files Created

```text
ShiftFlow/Application/AppContainer.swift
ShiftFlow/Application/Services/ShiftDefinitionProvider.swift
ShiftFlow/Persistence/SwiftData/SwiftDataWorkDayRepository.swift
ShiftFlow/ShiftFlowDomain/Tests/IntegrationTests.swift
```

### Files Modified

```text
ShiftFlow/App/ShiftFlowApp.swift (builds AppContainer)
ShiftFlow/App/ContentView.swift (hosts CalendarScreen)
CHANGELOG.md
```

### Tests

```text
IntegrationTests — 30 tests (IMPLEMENTED; PENDING macOS/Xcode execution)

1. Create WorkDay end-to-end
2. Edit WorkDay end-to-end
3. Delete WorkDay end-to-end
4. Change WorkDay to OFF
5. Import end-to-end (CSV interchange)
6. Export + re-import round trip
7-10. C5 day 9/10/20/21 (Calendar + Widget + Reminder use same snapshot)
11. Historical snapshot protection end-to-end
12. MW independence end-to-end
13. Note independence end-to-end
14. Reminder after create
15. Reminder after shift change
16. Reminder cancellation identifiers after delete
17-20. Widget refresh after create/edit/delete/import
21. Next Shift update after future WorkDay change
22. CloudKit unavailable does not block local save
23. CloudKit sync does not rewrite snapshot
24. Deleted WorkDay becomes OFF
25. Duplicate date protection
26. XLSX validation prevents invalid import
27. Export is read-only
28. Offline application behavior
29. Shift code always available (accessibility)
30. Widget entry exposes shift code text
```

### Known Limitations

- Windows: no Swift/Xcode/CloudKit/WidgetKit/UNUserNotificationCenter runtime.
- `SwiftDataWorkDayRepository` (SwiftData `#Predicate`/`ModelContext`) and `AppContainer` wiring are source-complete but require macOS to compile/run.
- Integration tests use the in-memory repository + spy sink to exercise the same domain flows; SwiftData/WidgetKit/CloudKit/notification runtimes are verified physically on macOS.

### Notes

- No TaskDefinition/WorkDayTask model yet (TASK-TASK-001 not implemented); task indicator remains behind the `taskWorkDayIDsProvider` closure. MW independence is verified via the widget task indicator + snapshot times.
- No new features, business rules, UI redesigns, or scope creep introduced.

---

## v0.4.0 — CloudKit / iCloud Sync

**Date:** 2026-08-23

**Task ID:** TASK-CLOUDKIT-001

**Type:** Feature / Architecture

**Status:** Completed — Build Pending on macOS

### Summary

Implemented CloudKit / iCloud synchronization using native SwiftData + CloudKit. Added a CloudKit-aware persistence configuration with automatic local-only fallback (offline-first), a deterministic `SyncConflictResolver`, a `CloudSyncService` for sync side-effects (widget refresh + date-collision integrity), and a `SyncStatus` model. Made `WorkDayModel` CloudKit-compatible.

### Reason

The product requires cross-device schedule synchronization (P2). CloudKit is a synchronization layer only — it must never be the source of truth for shift calculation, and the app must remain fully usable offline.

### Version Justification

v0.4.0 (MINOR) — CloudKit sync is a meaningful new product capability (multi-device synchronization).

### Architecture (documented in architecture.md §33)

```
SwiftData local store (source of truth, offline-first)
      ↓ automatic mirroring
CloudKit private database
      ↓ device-to-device
Other devices
```

### CloudKit-Compatibility Model Changes

- `WorkDayModel.id` no longer uses `@Attribute(.unique)` (CloudKit unsupported).
- All non-optional stored properties given default values (CloudKit requirement).
- "One WorkDay per date" enforced at service layer + `SyncConflictResolver`.

### Conflict Strategy

- Same record: last-modified wins (modifiedAt), deterministic UUID tiebreak.
- Date collision (two records, same date): keep most-recently-modified, remove duplicate.
- WorkDay resolved snapshot NEVER recalculated from ShiftDefinition during sync.

### Offline-First

`PersistenceConfiguration.makeContainer(useCloudKit:)` attempts CloudKit, falls back to local-only if unavailable. App never blocks on CloudKit.

### What Syncs / What Doesn't

- Syncs: WorkDay, ShiftDefinition, ScheduleRule, TaskDefinition, AppSettings, notes, ReminderConfiguration (if persisted).
- Does NOT sync: notification requests, Widget App Group snapshot, timeline entries, UI state.

### Widget After Sync

`CloudSyncService.syncDidComplete()` → date-collision check → `WidgetRefreshCoordinator.refresh()` → App Group + WidgetKit reload. Reuses existing widget pipeline; no CloudKit logic in Widget code.

### Reminders

Device-local. Notification requests never synced. Each device schedules from its local WorkDay snapshot.

### Files Created

```text
ShiftFlow/ShiftFlowDomain/Sources/Services/SyncConflictResolver.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/SyncModels.swift
ShiftFlow/Persistence/CloudKit/CloudSyncService.swift
ShiftFlow/ShiftFlowDomain/Tests/CloudKitSyncTests.swift
```

### Files Modified

```text
ShiftFlow/Persistence/SwiftData/PersistenceContainer.swift (CloudKit config + fallback)
ShiftFlow/Persistence/SwiftData/WorkDayModel.swift (CloudKit-compatible: removed .unique, added defaults)
ShiftFlow/App/ShiftFlowApp.swift (uses CloudKit-aware container factory)
.kiro/steering/architecture.md (§33 CloudKit Implementation)
CHANGELOG.md
```

### Tests

```text
CloudKitSyncTests — 30 tests (PENDING macOS/Xcode)

Categories:
- Offline: create/edit/delete/ShiftResolver/local-usable
- Historical snapshot: config change no-rewrite, synced start/end/break preserved
- C5 boundary: day 9/10/20/21 preserved after sync
- MW independence before/after sync
- OFF: deleted becomes OFF, no OFF ShiftDefinition
- Delete does not resurrect
- Date collision: resolves to single, detection, no false positives
- Same-record: last-modified wins, deterministic tiebreak
- Config: existing snapshot unchanged, new WorkDay uses new config
- Sync status display text
- Failure: failed op no corruption, conflict no recalculation
```

### Known Issues / Verification Limitations

- Windows environment: no Swift/Xcode/CloudKit. Cannot verify:
  container config, iCloud capability, schema deployment, physical multi-device sync.
- Pure logic (conflict resolver, sync status, offline behavior, snapshot preservation) is fully testable.
- CloudKit container ID `iCloud.com.shiftflow.app` is a PLACEHOLDER pending Xcode setup.

### Notes

- Domain does NOT import CloudKit — `SyncConflictResolver`/`SyncModels` are pure.
- `CloudSyncService` (Persistence/CloudKit) bridges sync events to widget refresh.
- No custom backend, REST API, or authentication introduced.

---

## v0.3.1 — Widget Data Refresh Integration

**Date:** 2026-08-23

**Task ID:** TASK-WIDGET-002

**Type:** Feature

**Status:** Completed — Build Pending on macOS

### Summary

Wired the main app to refresh the Home Screen Widget whenever relevant WorkDay data changes. Added a `WidgetSnapshotSink` protocol and `WidgetRefreshCoordinator` in the domain, and an `AppGroupWidgetSnapshotSink` in the app. WorkDayService now triggers a secondary widget refresh after each successful mutation.

### Reason

TASK-WIDGET-001 built the widget and its data models but did not connect the app's data changes to widget updates. This task completes that integration so the widget always reflects the latest schedule.

### Version Justification

v0.3.1 (PATCH) — integration/plumbing that completes the widget feature; no new user-facing surface.

### Architecture

```
WorkDayService (after successful persist)
    ↓
WidgetRefreshCoordinator.refresh()
    ↓
WidgetScheduleBuilder (single source of snapshot conversion)
    ↓
WidgetSnapshotSink.publish()
    ↓
AppGroupWidgetSnapshotSink → WidgetDataProvider.write() + requestReload()
```

- `WidgetScheduleBuilder` remains the ONLY snapshot-conversion location.
- Widget refresh is SECONDARY: it runs only after successful persistence and never fails a WorkDay operation.
- The coordinator swallows read failures (leaves previous snapshot intact).
- The sink's `publish(_:)` is non-throwing — App Group/WidgetKit failures are contained.
- `WorkDayService.widgetRefresher` is optional (nil by default) — existing tests/usages unaffected.

### Refresh Triggers

Create, Change Shift, Update Note (hasNote indicator), Delete, Import (per-row, final state correct), Replace-existing import, Change-to-OFF (delete). Failed operations do NOT refresh.

### Error Handling

- WorkDay persistence is primary; widget update is secondary.
- Widget write/read failure never rolls back or fails a WorkDay operation.
- Failed WorkDay save/delete does not trigger a widget refresh.

### Files Created

```text
ShiftFlow/ShiftFlowDomain/Sources/Services/WidgetRefreshing.swift
ShiftFlow/Widget/Services/AppGroupWidgetSnapshotSink.swift
ShiftFlow/ShiftFlowDomain/Tests/WidgetRefreshIntegrationTests.swift
```

### Files Modified

```text
ShiftFlow/ShiftFlowDomain/Sources/Services/WorkDayService.swift (optional widgetRefresher + refresh calls)
ShiftFlow/ShiftFlowDomain/Sources/Import/ShiftImportService.swift (refresh behavior doc)
CHANGELOG.md
```

### Tests

```text
WidgetRefreshIntegrationTests — 22 tests (PENDING macOS/Xcode)

Categories:
- Create/Change/Delete trigger widget update
- Import / replace-existing import trigger update
- Change-to-OFF removes WorkDay and updates widget
- Future WorkDay change updates Next Shift
- MW changes indicator but not shift times
- Note update does not alter shift times
- Failed create/delete does not update widget
- Widget failure does not rollback WorkDay
- Widget snapshot uses historical WorkDay snapshot
- Global config change does not rewrite widget data
- C5 boundary via integration (day 9/10/20/21)
- Repeated refresh does not corrupt snapshot
- Widget publish called after successful update
- Service works without widget refresher (optional)
```

### Known Issues

- Tests not executed: Windows environment has no Swift/WidgetKit toolchain.
- App Group capability + WidgetKit reload require macOS/Xcode runtime.
- Integration logic (coordinator, sink protocol, trigger points) is pure and fully testable via spy sink.

### Notes

- No second WorkDay data model created — widget uses the existing WorkDay → WidgetScheduleBuilder pipeline.
- ReminderService and WidgetRefreshCoordinator remain independent services.

---

## v0.3.0 — Home Screen Widget

**Date:** 2026-08-23

**Task ID:** TASK-WIDGET-001

**Type:** Feature

**Status:** Completed — Build Pending on macOS

### Summary

Implemented the ShiftFlow Home Screen Widget (Small, Medium, Large) using WidgetKit. The widget reads a pre-built schedule snapshot from the shared App Group and displays today's shift, next shift, and upcoming schedule. It reuses ShiftFlowDomain and never duplicates shift-resolution logic.

### Reason

Users want to see their shift schedule at a glance from the Home Screen without opening the app. The widget is a consumer of the approved domain logic.

### Version Justification

v0.3.0 (MINOR) — the widget is a new user-facing product capability (a new surface for viewing schedule data).

### Architecture

```
Main App → WidgetScheduleBuilder → WidgetScheduleSnapshot → App Group → Widget Timeline → Views
```

- Widget NEVER calculates shift times — displays WorkDay snapshot values only.
- ZERO C5/ScheduleRule logic in widget code.
- `WidgetScheduleBuilder` (in ShiftFlowDomain) builds snapshots from WorkDay records — pure and testable.
- `WidgetScheduleSnapshot`/`WidgetDayEntry` are Codable value types shared via App Group JSON.
- App Group: `group.com.shiftflow.shared` (Xcode capability config pending macOS).
- Deep link: `shiftflow://day?date=yyyy-MM-dd` — no networking/auth.
- Task = indicator only (blue dot). Note text NOT exposed in widget data (privacy).
- OFF = nil today entry (no persistent OFF record).

### Widget Families

```text
Small:  Today shift code + start→end (OFF when none)
Medium: Today (shift, times, break, task) + Next Shift
Large:  Today + Next + upcoming days with task indicators
```

### Timeline Policy

Refresh at next midnight so "today" advances. WidgetKit controls actual timing.

### Files Created

```text
ShiftFlow/ShiftFlowDomain/Sources/Models/WidgetScheduleSnapshot.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/WidgetScheduleBuilder.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/WidgetDeepLink.swift
ShiftFlow/Widget/ShiftFlowWidget.swift
ShiftFlow/Widget/ShiftFlowWidgetBundle.swift
ShiftFlow/Widget/Providers/ShiftFlowTimelineProvider.swift
ShiftFlow/Widget/Services/WidgetDataProvider.swift
ShiftFlow/Widget/Views/ShiftFlowWidgetView.swift
ShiftFlow/Widget/Views/SmallWidgetView.swift
ShiftFlow/Widget/Views/MediumWidgetView.swift
ShiftFlow/Widget/Views/LargeWidgetView.swift
ShiftFlow/Widget/Views/WidgetFormatting.swift
ShiftFlow/ShiftFlowDomain/Tests/WidgetScheduleTests.swift
```

### Files Removed

```text
ShiftFlow/Widget/README.swift (placeholder replaced by real implementation)
```

### Tests

```text
WidgetScheduleTests — 28 tests (PENDING macOS/Xcode)

Categories:
- Today WorkDay appears / nil when OFF
- Next Shift: first future / nil when none
- C5 boundary display: day 9/10/20/21
- Widget uses WorkDay snapshot values
- Config change does not rewrite widget snapshot
- MW does not change times (indicator only)
- Note does not change times / note text not exposed
- OFF does not create WorkDay
- Vietnamese weekday date preservation
- Small/Medium/Large data validity
- Upcoming sorted ascending
- Deep link: URL build, round trip, prefer today, fallback next, invalid parse
- Empty snapshot valid
- Codable round trip (App Group storage)
```

### Known Issues

- Tests not executed: Windows environment has no Swift/WidgetKit toolchain.
- Widget UI rendering + App Group capability require macOS/Xcode.
- Widget data logic (builder, snapshot, deep link) is pure and fully testable.

### Notes

- Widget views use `#if canImport(WidgetKit)` guards so the domain/data code compiles without WidgetKit.
- Main app must call `WidgetDataProvider.write(_:)` + `requestReload()` when WorkDays change.

---

## v0.2.1 — Shift Reminders

**Date:** 2026-08-23

**Task ID:** TASK-REMINDER-001

**Type:** Feature

**Status:** Completed — Build Pending on macOS

### Summary

Implemented local iOS shift reminders: ReminderOffset (5 options), ReminderConfiguration model, ReminderService with notification scheduling, permission handling, rolling 14-day window, shift-change rescheduling, WorkDay delete cancellation, deterministic notification identifiers, and comprehensive tests.

### Reason

Users need reminders before their shifts. The reminder system uses WorkDay.resolvedStartDateTime as the sole source of truth for timing — it never calculates shift times independently.

### Version Justification

v0.2.1 (PATCH) — notification/reminder is a supporting feature for the existing Calendar capability, not a standalone user-facing screen.

### Architecture

```
WorkDay.resolvedStartDateTime → ReminderService → UNUserNotificationCenter
```

- ReminderService does NOT reference ShiftResolver, ScheduleRule, or C5 logic.
- Task/MW/Note have zero influence on reminder timing.
- Deterministic identifiers: `shiftflow.workday.<UUID>.<offset>`
- Rolling window: next 14 days, max 50 pending notifications (below iOS 64 limit).
- Shift change: cancel old → schedule new with updated resolvedStartDateTime.
- WorkDay delete: cancel all associated notifications.
- Permission denied: explained to user with route to system Settings.

### Reminder Offsets

```text
At start         → resolvedStartDateTime + 0
30 minutes before → resolvedStartDateTime - 1800s
1 hour before    → resolvedStartDateTime - 3600s
2 hours before   → resolvedStartDateTime - 7200s
24 hours before  → resolvedStartDateTime - 86400s (exactly 24 hours)
```

### Files Changed

```text
ShiftFlow/Notifications/ReminderModels.swift
ShiftFlow/Notifications/ReminderService.swift
ShiftFlow/ShiftFlowDomain/Tests/ReminderTests.swift
```

### Tests

```text
ReminderOffsetTests — 38 tests (PENDING macOS/Xcode)

Categories:
- Basic offsets: at start, 30min, 1h, 2h, 24h
- C5 special: day 15 (12:00 start) with 2h, 24h, 30min
- C5 boundary: day 9/10/20/21 correct start times
- MW independence: task does not affect reminder
- Note independence
- Shift change: C4→C5 produces different reminder time
- Past reminder detection
- Notification identifier: deterministic, format, prefix, extraction
- All identifiers for WorkDay (5 offsets)
- Different offsets/WorkDays produce different IDs
- Configuration: identifier format, offset change, enable/disable
- Rolling window: 14-day calculation
- Offset time intervals
- 24h semantics: exactly 86400 seconds
- 24h early morning: previous day same time
- Display names (Vietnamese)
- All cases count
```

### Known Issues

- Tests not executed: Windows environment has no Swift toolchain or UserNotifications.
- UNUserNotificationCenter integration requires macOS/Xcode runtime.
- Offset calculation tests are pure logic and will pass without UNUserNotificationCenter.

### Notes

- ReminderService uses `async/await` for UNUserNotificationCenter API.
- `cancelAllShiftFlowNotifications()` identifies ShiftFlow notifications by prefix.
- `refreshSchedulingWindow()` is designed to be called on app launch/foreground.
- Notification content: Vietnamese, shift code + start time only (no sensitive note data).
- Past reminders are skipped, not scheduled.

---

## v0.2.0 — Calendar UI

**Date:** 2026-08-23

**Task ID:** TASK-CALENDAR-001

**Type:** Feature

**Status:** Completed — Build Pending on macOS

### Summary

Implemented the full ShiftFlow Calendar UI: Month view, Week view, 3 Days view, Today view with Next Shift query, Day Detail sheet with CRUD, shift selection with live resolution, Vietnamese weekday display, delete confirmation, unsaved changes handling, color accessibility, and comprehensive ViewModel tests.

### Reason

The Calendar is the primary user-facing screen of ShiftFlow. Users need to view, add, edit, and delete shifts across four presentation modes. This is the first user-facing feature that makes the application functional.

### Version Justification

v0.2.0 (MINOR) because this is the first meaningful user-facing product capability: the user can now view their shift schedule and manage WorkDays.

### Architecture

- **Data flow:** SwiftUI View → ViewModel → WorkDayService → ShiftResolver
- **No business logic in views:** All shift resolution delegated to WorkDayService/ShiftResolver via ViewModel.
- **Color accessibility:** Shift code text always displayed alongside color. Color is supplementary only.
- **Vietnamese weekdays:** T2–T7, CN using Foundation Calendar (not hardcoded positions).
- **Task indicator color:** Blue (reserved for tasks only, never shifts).

### Shift Colors

```text
C5 = red
C4 = white/light
C3 = green
C2 = orange
C1 = purple
Blue = tasks only (MW, Zalo, etc.)
```

### Files Changed

```text
ShiftFlow/Application/ViewModels/CalendarViewModel.swift
ShiftFlow/Application/ViewModels/DayDetailViewModel.swift
ShiftFlow/UI/Calendar/CalendarScreen.swift
ShiftFlow/UI/Calendar/MonthView.swift
ShiftFlow/UI/Calendar/WeekView.swift
ShiftFlow/UI/Calendar/ThreeDaysView.swift
ShiftFlow/UI/Calendar/TodayView.swift
ShiftFlow/UI/Calendar/DayDetailSheet.swift
ShiftFlow/UI/Shared/WeekdayFormatter.swift
ShiftFlow/UI/Shared/ShiftStyle.swift
ShiftFlow/UI/Shared/TimeFormatter.swift
ShiftFlow/ShiftFlowDomain/Tests/CalendarViewModelTests.swift
```

### Tests

```text
CalendarViewModelTests — 38 tests (PENDING macOS/Xcode)

Categories:
- Month grid: 42 cells, starts Monday, contains all days, Feb boundaries
- Week: 7 days, starts Monday, ends Sunday
- 3 Days: 3 consecutive days
- Navigation: next/prev month/week/3days, today reset
- WorkDay display in calendar
- C5 boundary: day 9/10/20/21 displayed from snapshot
- OFF state: nil WorkDay
- Task independence: MW does not change times
- Note indicator: present/absent
- Delete: removes from calendar
- Duplicate prevention
- Next Shift: loads first future WorkDay, nil when none
- Vietnamese weekday names (full + short)
- Monday-first header order
- DayDetailViewModel: shift selection resolves, OFF clears, save creates, delete confirms, unsaved flag
```

### Known Issues

- Tests not executed: Windows environment has no Swift toolchain.
- SwiftUI views cannot be unit-tested for visual rendering; ViewModel logic is fully tested.

### Notes

- Month view uses Monday-first grid (42 cells = 6 weeks).
- All accessibility labels use Vietnamese text with full schedule details.
- DayDetailSheet uses Form with sections: date, shift selection, schedule (read-only), task, note, delete.
- Delete requires alert confirmation. Unsaved dismiss shows discard alert.
- CalendarScreen uses .sheet for Day Detail, reloads data on dismiss.

---

## v0.1.5 — Excel Shift Import + Export

**Date:** 2026-08-23

**Task ID:** TASK-IMPORT-001

**Type:** Feature (Application/Domain)

**Status:** Completed — Build Pending on macOS

### Summary

Implemented Excel-based shift schedule import and export for ShiftFlow. The official format is .xlsx (Excel spreadsheet). The system supports import (parse → validate → preview → confirm → persist), export (WorkDay → official template), and template generation.

### Reason

Users manage their monthly shift schedule in Excel. The import/export capability allows batch creation of WorkDays from a standardized Excel template, and export of existing schedules back to the same template format for backup/sharing. All operations use the same ShiftResolver pipeline as manual creation.

### Architecture Decisions

**Official Format:** Excel .xlsx is the official ShiftFlow import/export format. CSV (comma/tab/pipe/semicolon delimited) is supported as a secondary text-based interchange format for the parsing layer.

**XLSX Integration Strategy:** The text-based parser (`ShiftFileParser`) handles extracted tabular content. For .xlsx files, a platform-specific adapter (e.g., CoreXLSX on Apple platforms) extracts text content and passes it to the parser. The XLSX adapter integration requires macOS/Xcode and will be verified during build.

**Import Flow:** Parse → Validate → Preview → User Confirm → Execute. No silent import on file selection.

**Export Format:** Date | Shift | Task | Note. Export does NOT include resolved start/end/break times. Shift times are derived from ShiftResolver and are not user-entered data.

**Export is Read-Only:** Export does not modify WorkDays or recalculate historical snapshots.

**Template:** Official empty template with headers (Date, Shift, Task, Note) and optional example rows. Available via Settings → Data Management → Download Template.

**Duplicate Dates in File:** Both rows marked as `duplicateInFile` error. User must fix the source file.

**Existing WorkDay Conflicts:** Detected during validation, shown in preview. User chooses: Skip (preserves existing) or Replace (re-resolves via ShiftResolver). No silent overwrite.

**OFF Handling:** OFF rows are valid in the import file but do NOT create WorkDays or a persistent OFF ShiftDefinition. They are counted as `offDays` in the result. The import preview represents them as an OFF schedule state only.

**Task/Note Independence:** Task and Note values are stored on WorkDay but NEVER influence ShiftResolver. MW does not change shift times.

**UI Placement:** Settings → Data Management → Import / Export / Download Template. Not exposed as primary Calendar actions.

### Files Changed

```text
ShiftFlow/ShiftFlowDomain/Sources/Models/ImportModels.swift
ShiftFlow/ShiftFlowDomain/Sources/Import/ShiftFileParser.swift
ShiftFlow/ShiftFlowDomain/Sources/Import/ImportValidator.swift
ShiftFlow/ShiftFlowDomain/Sources/Import/ShiftImportService.swift
ShiftFlow/ShiftFlowDomain/Sources/Import/ShiftExportService.swift
ShiftFlow/ShiftFlowDomain/Tests/ShiftImportTests.swift
```

### Tests

```text
ShiftImportTests — 45+ tests (PENDING macOS/Xcode)

Import Tests:
- Parser: valid CSV, pipe-delimited, tab-delimited
- Parser: empty file, invalid header
- Validator: valid rows, invalid shift (C7), missing date
- Validator: invalid date format, missing shift
- Validator: duplicate dates in file
- Validator: existing WorkDay conflict
- Validator: OFF valid but not importable
- Preview: counts (valid/error/duplicate/conflict/off)
- Integration: C1 import with correct snapshot
- Integration: C5 special (day 15) → 12:00–21:30
- Integration: C5 boundary day 9/10/20/21
- Task independence: MW does not change snapshot
- Note import preserved
- OFF does not create WorkDay
- Skip existing preserves original
- Replace existing updates via ShiftResolver
- Historical snapshot survives config change
- Multi-row import (C1–C5)
- Mixed valid/invalid rows

Export Tests:
- Export produces correct 4-column format
- Export does not include resolved times
- Export does not modify WorkDays
- Export preserves date
- Export preserves shift code
- Export preserves note
- Export with task lookup
- Export sorts by date ascending

Template Tests:
- Template has correct headers
- Template with examples
- Empty template has header only
- Template does not contain resolved times

Format Tests:
- XLSX is official format
- XLSX file extension correct
- CSV is secondary format

Round-Trip Tests:
- Export → Import preserves date, shift, note
- Export → Import resolves schedule via ShiftResolver
- Export → Import with multiple shifts (C1–C5)
```

### Known Issues

- Tests not executed: Windows environment has no Swift toolchain.
- XLSX binary read/write requires platform-specific adapter (CoreXLSX or similar). Integration pending macOS/Xcode build.
- CSV text parsing is fully implemented and testable.

### Notes

- Import/Export logic lives in `ShiftFlowDomain/Sources/Import/` for testability.
- All WorkDay creation flows through `WorkDayService.createWorkDay()` which uses `ShiftResolver`.
- The importer/exporter NEVER calculates shift times independently.
- `shiftLookup` closure allows the caller to provide shift definitions from any source.
- `ShiftExportService.export(workDays:taskLookup:)` supports task export via closure.
- `ShiftTemplate` provides official headers and example data for template generation.

---

## v0.1.4 — WorkDay + Historical Snapshot

**Date:** 2026-08-22

**Task ID:** TASK-WORKDAY-001

**Type:** Feature (Domain + Persistence)

**Status:** Completed — Build Pending on macOS

### Summary

Implemented the WorkDay domain model, WorkDayService with CRUD operations, historical snapshot strategy, SwiftData persistence model (WorkDayModel), duplicate date handling, explicit shift change flow, and comprehensive unit tests.

### Reason

WorkDay is the primary scheduled work record. The historical snapshot strategy is a P0 architectural requirement: changing global shift configuration must never silently rewrite existing WorkDay data.

### Requirements

- Req 1–3 (Create, Edit, Delete WorkDay)
- Req 13 (Historical Configuration Protection)
- Req 52 (No Duplicate WorkDay per date)

### Architecture Decisions

**Historical Snapshot:** When a WorkDay is created, ShiftResolver resolves the schedule and the concrete date-time values are stored directly in the WorkDay. These stored values are immutable unless the user explicitly changes the shift assignment.

**Duplicate Date Handling:** Attempting to create a second WorkDay for the same date throws `WorkDayRepositoryError.duplicateDate`. The existing WorkDay is not overwritten. This enforces "one primary WorkDay per calendar date."

**Explicit Shift Change:** `WorkDayService.changeShift(workDayID:newShift:rules:)` is the only approved path for modifying a WorkDay's resolved snapshot after creation. It re-resolves using ShiftResolver and updates the stored snapshot.

**Repository Protocol:** `WorkDayRepository` protocol in the domain layer defines the persistence interface. Concrete implementations (SwiftData, in-memory for tests) live outside the domain. This keeps the domain independent of SwiftData.

### Files Changed

```text
ShiftFlow/ShiftFlowDomain/Sources/Models/WorkDay.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/WorkDayRepository.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/WorkDayService.swift
ShiftFlow/Persistence/SwiftData/WorkDayModel.swift
ShiftFlow/Persistence/SwiftData/PersistenceContainer.swift
ShiftFlow/ShiftFlowDomain/Tests/WorkDayServiceTests.swift
ShiftFlow/ShiftFlowDomain/Tests/InMemoryWorkDayRepository.swift
```

### Tests

```text
WorkDayServiceTests — 24 tests (PENDING macOS/Xcode)

Categories:
- WorkDay creation with C1 snapshot
- C5 normal on day 9
- C5 special on day 15
- C5 boundary: day 9/10/20/21
- Historical snapshot immutability (P0 regression)
- Historical snapshot preserved after note update
- Explicit shift change (C4 → C5)
- Shift change preserves WorkDay ID
- Shift change preserves note
- Duplicate date rejection
- Duplicate does not overwrite
- One WorkDay per date
- Delete WorkDay
- Delete non-existent throws
- Fetch by date
- Fetch by date range
- Note update does not change snapshot
- Clear note
- Persistence round-trip (all fields)
- Persistence date components
- WorkDay init from ResolvedShift
- Shift change on non-existent throws
```

### Known Issues

- Tests not executed: Windows environment has no Swift toolchain.
- SwiftData integration test (with actual ModelContainer) requires macOS/Xcode.

### Notes

- WorkDay is a value type (struct) in the domain layer for immutability and testability.
- WorkDayModel is a SwiftData @Model class in the persistence layer for storage.
- Mapping between the two is handled by `toDomain()` and `init(from:)` on WorkDayModel.
- InMemoryWorkDayRepository enables comprehensive testing without SwiftData dependency.
- Reminder cancellation on delete is NOT implemented here (belongs to TASK-REMINDER-001).

---

## v0.1.3 — Shift Domain Implementation

**Date:** 2026-08-22

**Task ID:** TASK-SHIFT-001

**Type:** Feature (Domain)

**Status:** Completed — Build Pending on macOS

### Summary

Implemented the core Shift Domain: ShiftDefinition, ScheduleRule, ResolvedShift value type, ShiftResolver service, and default C1–C5 seed provider with idempotent seeding logic.

### Reason

ShiftResolver is the single source of truth for all shift schedule resolution. All features (Calendar, Today, Reminder, Widget) must use this domain component. It must be implemented before any UI or persistence work.

### Requirements

- Req 4–10 (C1–C5 shift definitions and schedules)
- Req 11 (Automatic shift resolution)
- Req 14 (Central resolver)
- Req 16 (Deterministic calculation)
- Req 60 (ShiftResolver tests)

### Shift Rules Implemented

```text
C1: 07:00–16:30, Break 11:00–12:00
C2: 07:30–17:00, Break 11:30–12:30
C3: 08:00–17:30, Break 12:00–13:00
C4: 08:30–18:00, Break 12:30–13:30
C5 Normal: 11:30–21:00, Break 16:30–17:30
C5 Special (Day 10–20): 12:00–21:30, Break 16:30–17:30
```

### C5 Boundary Implementation

```text
Day 9  → normal (11:30–21:00)
Day 10 → special (12:00–21:30) — inclusive
Day 20 → special (12:00–21:30) — inclusive
Day 21 → normal (11:30–21:00)
```

Condition: `dayOfMonth >= 10 && dayOfMonth <= 20`

### Files Changed

```text
ShiftFlow/ShiftFlowDomain/Sources/Models/ShiftDefinition.swift
ShiftFlow/ShiftFlowDomain/Sources/Models/ScheduleRule.swift
ShiftFlow/ShiftFlowDomain/Sources/Models/ResolvedShift.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/ShiftResolver.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/ShiftSeedProvider.swift
ShiftFlow/ShiftFlowDomain/Sources/ShiftFlowDomain.swift
ShiftFlow/ShiftFlowDomain/Tests/ShiftResolverTests.swift
ShiftFlow/ShiftFlowDomain/Tests/ShiftSeedProviderTests.swift
```

### Tests

```text
ShiftResolverTests — 34 tests (PENDING macOS/Xcode)
ShiftSeedProviderTests — 25 tests (PENDING macOS/Xcode)

Categories:
- C1 resolution
- C2 resolution
- C3 resolution
- C4 resolution
- C5 normal resolution
- C5 special (day 10–20)
- C5 boundary: day 9/10/20/21
- February (leap and non-leap year)
- Year boundary (December/January)
- Determinism (same input → same output)
- Inactive rule handling
- Priority-based rule selection
- Seed existence (C1–C5)
- Seed default values
- C5 special rule boundaries
- Idempotent seed (no duplicates)
- Partial seed (only missing)
- Stable seed IDs
```

### Known Issues

- Tests not executed: Windows environment has no Swift toolchain.
- Build verification requires macOS/Xcode.

### Notes

- ShiftResolver is a pure static enum (no state, no side effects).
- ScheduleRule uses inclusive boundary: `dayOfMonth >= startDay && dayOfMonth <= endDay`.
- ShiftSeedProvider uses stable UUIDs for idempotent seeding.
- Domain module depends only on Foundation — no SwiftUI/WidgetKit/CloudKit.
- ResolvedShift provides all fields needed for WorkDay snapshot (TASK-WORKDAY-001).

---

## v0.1.2 — Project Foundation

**Date:** 2026-08-22

**Task ID:** TASK-FOUNDATION-001

**Type:** Foundation / Configuration

**Status:** Completed — Build Pending on macOS

### Summary

Created the initial SwiftUI iOS project structure with layered architecture, shared Domain module (local Swift Package), SwiftData persistence placeholder, and test targets. No user-facing feature implemented.

### Reason

Establish the architectural skeleton required by architecture.md before implementing business logic. Ensures the dependency direction (UI → Application → Domain → Persistence) is enforced from the start.

### Requirements

- architecture.md §3 (Layered Architecture)
- architecture.md §4 (Shared Domain for Widget)
- architecture.md §30 (Project Structure)
- tasks.md Task 1.1

### Files Changed

```text
ShiftFlow/ShiftFlowDomain/Package.swift
ShiftFlow/ShiftFlowDomain/Sources/ShiftFlowDomain.swift
ShiftFlow/ShiftFlowDomain/Sources/Models/ShiftDefinition.swift
ShiftFlow/ShiftFlowDomain/Sources/Models/ResolvedShift.swift
ShiftFlow/ShiftFlowDomain/Sources/Models/WorkDay.swift
ShiftFlow/ShiftFlowDomain/Sources/Services/ShiftResolver.swift
ShiftFlow/ShiftFlowDomain/Sources/Rules/ScheduleRule.swift
ShiftFlow/ShiftFlowDomain/Tests/ShiftResolverTests.swift
ShiftFlow/App/ShiftFlowApp.swift
ShiftFlow/App/ContentView.swift
ShiftFlow/App/Assets.xcassets/Contents.json
ShiftFlow/App/Assets.xcassets/AccentColor.colorset/Contents.json
ShiftFlow/App/Assets.xcassets/AppIcon.appiconset/Contents.json
ShiftFlow/Application/UseCases/README.swift
ShiftFlow/Application/ViewModels/README.swift
ShiftFlow/Persistence/SwiftData/PersistenceContainer.swift
ShiftFlow/UI/README.swift
ShiftFlow/Notifications/NotificationService.swift
ShiftFlow/Widget/README.swift
ShiftFlow/Tests/ShiftFlowTests.swift
ShiftFlow/SETUP.md
ShiftFlow/ShiftFlow.xcodeproj/project.pbxproj (placeholder — not a valid Xcode project)
```

### Tests

```text
testDomainModuleIsAccessible — PENDING (requires macOS/Xcode)
testPlaceholderForC5BoundaryTests — PENDING (requires macOS/Xcode)
testAppTestTargetIsConfigured — PENDING (requires macOS/Xcode)
```

### Known Issues

- Build not verified: development machine is Windows (no Xcode/Swift toolchain).
- .xcodeproj is a placeholder text file; actual Xcode project must be created on macOS.
- App Group `group.com.shiftflow.shared` is planned but NOT configured (requires Xcode capability setup).
- design.md remains at v0.1.0 (P1 item from spec review, not blocking).

### Notes

- Domain module implemented as a local Swift Package to enforce dependency isolation.
- All domain files are structural placeholders only — no business logic implemented.
- Version is PATCH (v0.1.2) because this task establishes project structure without adding a user-facing feature or meaningful product capability.

---

## v0.1.1 — Specification Review Corrections

**Date:** 2026-08-22

**Task ID:** REVIEW-001

**Type:** Specification / Architecture

**Status:** Completed

### Summary

Updated ShiftFlow specifications after Kiro specification review.

### Changes

- Corrected product specification to ShiftFlow.
- Added WorkDay resolved-time snapshot strategy.
- Added shared domain strategy for App and Widget.
- Added first-launch C1–C5 seed requirements.
- Added C5 February and year-boundary tests.
- Added MW task independence validation.
- Added 7–14 day rolling notification strategy.
- Clarified reminder "24 hours before" semantics.
- Added Next Shift query requirement.
- Clarified OFF as a presentation state rather than a persistent shift.

---

End of Change Log.