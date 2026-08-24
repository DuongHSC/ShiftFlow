# Design Document

**Project:** ShiftFlow  
**Version:** v0.1.1  
**Status:** Baseline  
**Product:** ShiftFlow  
**Platform:** iOS  

---

## Overview

ShiftFlow is a personal iOS shift-management application that allows users to assign shifts to dates, automatically resolve working hours, attach tasks and notes, configure reminders, and view schedules across multiple calendar views and a Home Screen Widget.

The application follows a layered architecture with a shared Domain module that serves both the main iOS application and the Widget extension. The central ShiftResolver provides deterministic schedule calculation independent of UI, network, or platform-specific frameworks.

The primary design goal is:

> Open ShiftFlow and immediately know what shift I have today, what tasks I have, and what my upcoming schedule looks like.

---

## Architecture

### Layered Structure

```
┌───────────────────────────────┐
│            UI Layer           │
│ SwiftUI Views / ViewModels    │
└───────────────┬───────────────┘
                ↓
┌───────────────────────────────┐
│       Application Layer       │
│ Use Cases / Services / State  │
└───────────────┬───────────────┘
                ↓
┌───────────────────────────────┐
│          Domain Layer         │
│ ShiftResolver / Rules /       │
│ ResolvedShift / domain logic  │
└───────────────┬───────────────┘
                ↓
┌───────────────────────────────┐
│       Persistence Layer       │
│ SwiftData / CloudKit adapter  │
└───────────────────────────────┘
```

### Dependency Direction

Allowed:

```
UI → Application → Domain → Persistence
```

Domain MUST NOT depend on:

- SwiftUI
- WidgetKit
- UserNotifications
- CloudKit

### Shared Domain Module

ShiftFlowDomain is a local Swift Package shared by:

- Main iOS application target
- Widget extension target
- Unit test targets

The domain module contains:

- ShiftDefinition (model)
- ScheduleRule (model)
- ResolvedShift (value type)
- ShiftResolver (service)

This ensures a single source of truth for schedule calculation.

### Technology Stack

```
Swift 5.9+
SwiftUI (UI layer)
SwiftData (local persistence)
UserNotifications (reminders)
WidgetKit (Home Screen Widget)
CloudKit (P2 — later synchronization layer)
```

---

## Components and Interfaces

### ShiftResolver

**Purpose:** Central schedule calculation service.

**Input:**

- Date
- ShiftDefinition
- Active ScheduleRules

**Output:**

- ResolvedShift (start, end, break start, break end for the given date)

**Properties:**

- Deterministic: same inputs always produce same output.
- Pure: no side effects, no network, no UI dependency.
- Independently testable.

**C5 Resolution Logic:**

```
IF dayOfMonth >= 10 AND dayOfMonth <= 20:
    start = 12:00, end = 21:30, breakStart = 16:30, breakEnd = 17:30
ELSE:
    start = 11:30, end = 21:00, breakStart = 16:30, breakEnd = 17:30
```

Boundary behavior:

```
Day 9  → normal (11:30–21:00)
Day 10 → special (12:00–21:30)
Day 20 → special (12:00–21:30)
Day 21 → normal (11:30–21:00)
```

The rule is evaluated independently for every month.

### NotificationService

**Purpose:** Schedule and cancel local notifications based on resolved WorkDay data.

**Interface:**

- scheduleReminder(workDay, offset) → schedules notification
- cancelReminder(workDayID) → cancels notification
- reconcileReminders() → reconciles rolling window

**Constraints:**

- Must NOT independently calculate shift times.
- Uses WorkDay resolved snapshot for scheduling.
- Uses rolling 7–14 day scheduling window.
- Deterministic notification identifier: `shiftflow.reminder.<workday-id>`

### WidgetService

**Purpose:** Coordinate widget data and refresh.

**Interface:**

- requestReload() → calls WidgetCenter.shared.reloadAllTimelines()

**Constraints:**

- Widget reads shared data from App Group container.
- Widget uses ShiftFlowDomain for any domain logic.
- Widget must NOT duplicate C5 day 10–20 logic.
- WidgetKit controls actual refresh timing.

### PersistenceService

**Purpose:** Manage SwiftData ModelContainer and data access.

**Interface:**

- Provides ModelContainer configuration.
- Planned App Group: `group.com.shiftflow.shared` (for Widget data sharing).

**Constraints:**

- Local store is primary source of truth.
- App must be fully usable without CloudKit.
- CloudKit is a later synchronization layer.

### CloudSyncService (P2)

**Purpose:** Synchronize data between devices via CloudKit.

**Synced data:** WorkDay, ShiftDefinition, ScheduleRule, TaskDefinition, AppSettings.

**Device-local data:** Notification registrations, widget timeline state.

**Conflict policy:** Last modification wins (using modifiedAt timestamp).

---

## Data Models

### ShiftDefinition

```
id: UUID
code: String (C1, C2, C3, C4, C5)
name: String
startTime: Time (HH:mm)
endTime: Time (HH:mm)
breakStart: Time (HH:mm)
breakEnd: Time (HH:mm)
isActive: Bool
createdAt: Date
modifiedAt: Date
```

### ScheduleRule

```
id: UUID
shiftID: UUID (reference to ShiftDefinition)
startDayOfMonth: Int (1–31)
endDayOfMonth: Int (1–31)
startTime: Time (HH:mm)
endTime: Time (HH:mm)
breakStart: Time (HH:mm)
breakEnd: Time (HH:mm)
priority: Int
isActive: Bool
```

### ResolvedShift (value type, not persisted independently)

```
shiftID: UUID
shiftCode: String
date: Date
startDateTime: DateTime
endDateTime: DateTime
breakStartDateTime: DateTime
breakEndDateTime: DateTime
```

### WorkDay

```
id: UUID
date: Date (calendar date, unique constraint)
shiftID: UUID (reference to ShiftDefinition)
resolvedStartDateTime: DateTime
resolvedEndDateTime: DateTime
resolvedBreakStartDateTime: DateTime
resolvedBreakEndDateTime: DateTime
note: String? (optional plain text)
reminderEnabled: Bool
reminderOffset: TimeInterval?
createdAt: Date
modifiedAt: Date
```

Relationships:

```
WorkDay ──→ ShiftDefinition (reference)
WorkDay ──→ Tasks (one-to-many)
```

### TaskDefinition

```
id: UUID
name: String (e.g., "MW", "Zalo")
isActive: Bool
createdAt: Date
modifiedAt: Date
```

### WorkDayTask (join)

```
id: UUID
workDayID: UUID
taskDefinitionID: UUID
```

### Historical Snapshot Strategy

When a WorkDay is created or its shift is changed:

```
Date + Shift → ShiftResolver → ResolvedShift → Snapshot into WorkDay
```

The WorkDay stores resolved start, end, break start, break end as a point-in-time snapshot. Changing global ShiftDefinition or ScheduleRule MUST NOT silently rewrite existing WorkDay snapshots.

A snapshot is recalculated only when:

- A new WorkDay is created.
- The WorkDay's selected shift is changed.
- The user explicitly requests schedule recalculation.

### OFF State

No persistent OFF ShiftDefinition exists. If no WorkDay record exists for a date, that date is considered OFF (no scheduled work). The UI renders this state; it is not stored.

### First-Launch Seed

On first launch, if no shift definitions exist, the system seeds C1–C5 with default values. The seed operation is idempotent and must not create duplicates.

---

## Correctness Properties

### Property 1: MW Task Independence

Adding or removing MW (or any task) to a WorkDay MUST NEVER change the WorkDay's resolved start time, end time, break start, or break end.

### Property 2: Historical Snapshot Immutability

Changing a global shift configuration (ShiftDefinition or ScheduleRule) MUST NEVER modify the resolved snapshot stored in any existing WorkDay record.

### Property 3: C5 Special Schedule (Day 10–20)

When shift C5 is resolved for a date where dayOfMonth is between 10 and 20 inclusive, the resolved times MUST be start 12:00, end 21:30, break start 16:30, break end 17:30.

### Property 4: C5 Normal Schedule (Outside Day 10–20)

When shift C5 is resolved for a date where dayOfMonth is less than 10 or greater than 20, the resolved times MUST be start 11:30, end 21:00, break start 16:30, break end 17:30.

### Property 5: Widget-App Consistency

The Widget extension and the main application MUST use the same ShiftFlowDomain module for schedule resolution. They must produce identical results for the same input.

### Property 6: Reminder Cleanup on Deletion

Deleting a WorkDay MUST cancel its associated local notification. No stale notifications may remain after WorkDay deletion.

### Property 7: Single WorkDay Per Date

For any calendar date, at most one primary WorkDay record SHALL exist in the data store.

---

## Error Handling

### Notification Permission Denied

- The system detects denied notification authorization.
- The system displays a message: "Notifications are disabled. Reminders require notification permission."
- The system provides a button to open iOS system Settings.
- The system does not repeatedly prompt if already denied.
- Reminder toggle is visually indicated as unavailable.

### SwiftData Persistence Failure

- The system displays: "Unable to save changes. Please try again."
- The system logs the error internally for debugging.
- The system does not crash or lose the user's in-memory edits immediately.
- The system retries on the next save attempt.

### CloudKit Unavailable (P2)

- The system displays: "iCloud sync is temporarily unavailable. Your local schedule is safe."
- The system continues to operate fully on local data.
- The system does not block UI waiting for CloudKit.
- The system retries synchronization when connectivity is restored.
- CloudKit failure MUST NOT delete valid local data.

### Sync Conflict (P2)

- The system uses "last modification wins" based on modifiedAt timestamp.
- The conflict resolution is deterministic.
- A newer local WorkDay is never overwritten by an older remote version.
- The system logs conflicts for diagnostic purposes.

### Invalid Shift Configuration

- The system validates that start time < end time for shift definitions.
- The system validates that break times fall within the shift time range.
- IF validation fails, THE SYSTEM SHALL display an error and reject the save without corrupting existing data.

### Missing WorkDay

- When no WorkDay exists for a date, the system displays the date as OFF.
- The system provides an "Add Shift" action for empty dates.
- The system does not generate error messages for normal OFF states.

### Widget Data Unavailable

- If the Widget cannot read shared data (e.g., App Group not configured, data corrupt), it displays a placeholder: "Open ShiftFlow to set up your schedule."
- The Widget does not crash on missing data.
- The Widget uses the most recent available timeline entry.

---

## Testing Strategy

### Unit Test Priority

1. **ShiftResolverTests** (P0) — C1, C2, C3, C4, C5 normal, C5 day 9/10/20/21, February, year boundary, leap year.
2. **WorkDayTests** (P0) — Create, edit, delete, snapshot integrity.
3. **HistoricalSnapshotTests** (P0) — Configuration change does not alter existing snapshots.
4. **TaskTests** (P0) — MW add/remove does not change times, multiple tasks.
5. **ReminderTests** (P0) — Schedule, update on shift change, cancel on deletion.
6. **DataIntegrityTests** (P1) — No duplicate WorkDay, task separation from shift.

### Integration Test Priority

7. **WidgetTests** (P2) — Widget uses shared domain, data consistency.
8. **CloudKitTests** (P2) — Sync, conflict resolution, offline resilience.

### Test Naming Convention

Tests should clearly describe expected behavior:

```
testC5UsesSpecialScheduleOnDay10()
testC5UsesNormalScheduleOnDay9()
testC5UsesNormalScheduleOnDay21()
testAddingMWDoesNotChangeResolvedTimes()
testChangingConfigDoesNotAlterHistoricalSnapshot()
testDeletingWorkDayCancelsReminder()
```

### Required C5 Boundary Tests

```
C5 Day 9  → 11:30–21:00 (normal)
C5 Day 10 → 12:00–21:30 (special)
C5 Day 20 → 12:00–21:30 (special)
C5 Day 21 → 11:30–21:00 (normal)
C5 February 10 → special
C5 February 20 → special
C5 December 31 → normal (day > 20)
C5 January 1 → normal (day < 10)
Leap year February → correct resolution
Non-leap year February → correct resolution
```

---

## Performance Considerations

- Calendar month view should fetch WorkDays for the visible date range in a single query, not individual queries per day cell.
- Avoid repeated ShiftResolver invocations for already-resolved WorkDays (use persisted snapshot).
- Widget timeline should be precomputed for upcoming days rather than calculated on each refresh.
- Avoid blocking the main UI thread with persistence or notification operations.
- Do not prematurely optimize; measure before major optimization efforts.

---

## Security Considerations

- ShiftFlow is a personal application. No multi-user access control is required.
- User schedule data remains within the local device and iCloud private database.
- No analytics or tracking unless explicitly approved.
- Do not log private schedule content unnecessarily.
- No third-party data collection.
- Sensitive information (schedule details) should not appear in system logs or crash reports.

---

## Migration and Deployment

### Initial Deployment

- iOS 17.0 minimum deployment target.
- SwiftData as the local persistence layer (new in iOS 17).
- No migration needed for initial release (v1.0.0).

### Future Data Model Migrations

When data models change in future versions:

- SwiftData lightweight migration is preferred where possible.
- If a breaking model change is required, a versioned migration plan must be documented.
- Historical WorkDay snapshots must survive migrations intact.
- CloudKit schema changes must be forward-compatible.

### App Group Configuration

- Planned identifier: `group.com.shiftflow.shared`
- Required for Widget data access.
- Must be configured in Xcode Signing & Capabilities on macOS.
- Not yet active; will be enabled during Widget implementation phase.

### CloudKit Deployment (P2)

- Uses CloudKit private database (personal data only).
- CloudKit container must be created in Apple Developer portal.
- Schema deployment via CloudKit Dashboard.
- Core app must function without CloudKit configured.

---

## Navigation Design

### Primary Navigation

```
Calendar (default, primary screen)
Today (immediate daily information)
Settings (configuration and preferences)
```

### Calendar Flow

```
Calendar → Tap Day → Day Detail Sheet
Calendar → Add Shift → Day Detail Sheet
```

### Today Flow

```
Today → Edit → Day Detail Sheet
Today → Next Shift → Day Detail Sheet
```

### Settings Flow

```
Settings → Shift Configuration → Shift Edit
Settings → Task Configuration
Settings → Notifications
Settings → Sync Status
```

---

## UI Design Principles

- Simple, fast, clean, native to iOS.
- Shift code is always visible (not color-only).
- Month view is the default calendar view.
- Day Detail appears as a sheet over the calendar.
- Resolved working time is read-only (user changes shift, not time directly).
- Tasks are visually secondary to shifts.
- Notes use compact indicators in Month view.
- Do not become a general-purpose calendar (no hourly grid, attendees, invitations, multi-account).
- The core concept: Date → Shift → Task → Note.

---

## Widget Design

### Small Widget

Shows today's shift code, resolved working time, and task indicator.

### Medium Widget

Shows today's shift and next shift side by side.

### Large Widget

Shows a short schedule overview (today + 2–3 upcoming days).

### Constraints

- Widget uses shared ShiftFlowDomain module.
- Widget reads data from App Group shared container.
- Widget must not duplicate shift-resolution logic.
- WidgetKit controls refresh timing.
- Tapping the widget opens ShiftFlow (deep link possible in later phase).
