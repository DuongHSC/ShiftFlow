# ShiftFlow — Architecture Specification

**Document:** architecture.md
**Version:** v0.1.1
**Status:** Approved Baseline
**Platform:** iOS
**Architecture Style:** Layered / Domain-driven

---

# 1. Architecture Goals

ShiftFlow must be:

- Local-first
- Testable
- Configurable
- Native to iOS
- Simple to maintain
- Safe for historical schedule data
- Reusable across the main app and Widget
- Independent of CloudKit for core business logic

The most important architectural principle is:

> Shift schedule calculation must exist in one reusable domain component.

---

# 2. Technology Direction

Initial technology stack:

```text
Swift
SwiftUI
SwiftData
UserNotifications
WidgetKit
CloudKit
```

CloudKit is a later phase and must not be required for the core application to function.

---

# 3. Layered Architecture

Recommended structure:

```text
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

The UI must not contain business rules.

---

# 4. Shared Domain for Widget

The Widget is a separate target.

The following domain components must be reusable by both the main application and Widget:

```text
ShiftDefinition
ScheduleRule
ResolvedShift
ShiftResolver
```

Preferred implementation direction:

```text
Shared Swift Package / framework / shared target module
```

The final mechanism may be selected during project setup, but the domain API must remain independent of SwiftUI.

The Widget must never duplicate C5 logic.

---

# 5. Core Domain Model

## 5.1 ShiftDefinition

Represents a configurable shift.

Conceptual fields:

```text
id
code
name
startTime
endTime
breakStart
breakEnd
isActive
createdAt
modifiedAt
```

Example:

```text
C5
11:30 → 21:00
16:30 → 17:30
```

---

## 5.2 ScheduleRule

Represents a conditional schedule override.

Conceptual fields:

```text
id
shiftID
startDayOfMonth
endDayOfMonth
startTime
endTime
breakStart
breakEnd
priority
isActive
```

Current rule:

```text
C5
Day 10 → Day 20
12:00 → 21:30
16:30 → 17:30
```

The resolver applies the matching active rule.

---

## 5.3 ResolvedShift

`ResolvedShift` is a domain value/result, not a user configuration.

Conceptual fields:

```text
shiftID
shiftCode
date
startDateTime
endDateTime
breakStartDateTime
breakEndDateTime
```

It represents the exact schedule applicable to one date.

---

## 5.4 WorkDay

WorkDay is the primary scheduled work record.

Conceptual fields:

```text
id
date
shiftID
resolvedStartDateTime
resolvedEndDateTime
resolvedBreakStartDateTime
resolvedBreakEndDateTime
note
createdAt
modifiedAt
```

Relationships:

```text
WorkDay
 ├── ShiftDefinition reference
 ├── Tasks
 └── Reminder configuration
```

---

# 6. Historical Snapshot Strategy

This is an explicit architecture decision.

## Decision

When a WorkDay is created or its shift is changed:

```text
Date + Shift
      ↓
ShiftResolver
      ↓
ResolvedShift
      ↓
Snapshot resolved values into WorkDay
```

The WorkDay stores:

```text
resolvedStartDateTime
resolvedEndDateTime
resolvedBreakStartDateTime
resolvedBreakEndDateTime
```

## Why

This prevents future configuration changes from silently rewriting historical WorkDays.

Example:

```text
August 15
C5
12:00 → 21:30
```

Later C5 is changed to:

```text
13:00 → 22:00
```

August 15 must continue to display:

```text
12:00 → 21:30
```

unless the user explicitly edits that WorkDay.

---

# 7. Snapshot Update Rule

A WorkDay snapshot must be recalculated when:

```text
A new WorkDay is created
OR
The WorkDay's selected shift changes
OR
The user explicitly requests schedule recalculation
```

Changing a global shift configuration alone must NOT silently rewrite existing WorkDay snapshots.

---

# 8. ShiftResolver

`ShiftResolver` is the central schedule calculation service.

Input:

```text
date
shift definition
active schedule rules
```

Output:

```text
ResolvedShift
```

The resolver must be:

- Deterministic
- Pure where practical
- Independently testable
- Independent of SwiftUI
- Independent of CloudKit
- Independent of notifications

---

# 9. C5 Resolution

The resolver must implement:

```text
C5 normal:
11:30 → 21:00
Break 16:30 → 17:30

C5 day 10–20:
12:00 → 21:30
Break 16:30 → 17:30
```

Boundary tests:

```text
Day 9  → normal
Day 10 → special
Day 20 → special
Day 21 → normal
```

The rule is evaluated independently for every month.

---

# 10. First-Launch Seed Data

The application must seed the default five shift definitions on first launch if no shift definitions exist.

Seed:

```text
C1
C2
C3
C4
C5
```

The seeded values are the initial defaults only.

After seeding, the user may edit them from Settings.

The seed operation must be idempotent.

It must not create duplicate C1–C5 definitions.

---

# 11. OFF / No Shift

There is no persistent OFF ShiftDefinition in the MVP domain model.

Meaning:

```text
WorkDay exists
    → scheduled work

No WorkDay exists
    → no scheduled work
```

The UI may render this state as `OFF`.

This avoids unnecessary persistent records.

---

# 12. Task Model

Tasks are separate from shift definitions.

Conceptual:

```text
TaskDefinition
 ├── id
 ├── name
 ├── isActive
 └── timestamps

WorkDay
 └── Tasks
```

MW is an initial TaskDefinition.

Tasks must never contain working-hour calculation logic.

---

# 13. Note Model

A note is an optional property of WorkDay.

It is plain text.

Notes must not influence:

```text
ShiftResolver
Reminder calculation
Shift duration
```

---

# 14. Reminder Architecture

Use:

```text
UserNotifications
```

through a dedicated service such as:

```text
NotificationService
```

The service receives resolved WorkDay schedule information.

It must not calculate C1–C5 times independently.

---

# 15. Notification Rolling Window

iOS local notification scheduling has system limits.

ShiftFlow must use a rolling scheduling window rather than scheduling unlimited future reminders.

Initial strategy:

```text
Schedule reminders for approximately
the next 7–14 days.
```

The service should:

```text
Remove/reconcile stale ShiftFlow notifications
↓
Read upcoming WorkDays
↓
Use stored resolved times
↓
Schedule only the rolling window
```

The implementation must account for the iOS notification request limit.

The exact rolling window length may be configurable internally, but the initial target is 7–14 days.

---

# 16. Reminder Identity

Each reminder must have a deterministic identifier based on the WorkDay.

Conceptually:

```text
shiftflow.reminder.<workday-id>
```

When a WorkDay changes:

```text
Cancel identifier
↓
Schedule replacement
```

When deleted:

```text
Cancel identifier
```

This prevents stale reminders.

---

# 17. Notification Permission

Notification permission is a device-level concern.

The application must:

- Request permission only when appropriate.
- Detect denied authorization.
- Explain that reminders require notification permission.
- Provide a route to system Settings.

---

# 18. Widget Architecture

WidgetKit is responsible for presenting schedule data.

The Widget must:

```text
Read shared/local schedule data
        ↓
Use shared domain resolution where needed
        ↓
Build timeline entries
```

The Widget must not duplicate:

```text
C5 day 10–20 logic
Shift configuration rules
```

---

# 19. Widget Refresh

When relevant schedule data changes, the application should request a WidgetKit reload.

Example:

```text
WorkDay saved
     ↓
WidgetCenter reload request
```

However, WidgetKit controls actual refresh timing.

The application must not assume immediate real-time widget refresh.

---

# 20. Local Persistence

SwiftData is the initial local persistence technology.

The local store is the primary source of truth for the offline-first MVP.

The app must be fully usable without CloudKit.

---

# 21. CloudKit

CloudKit is a later synchronization layer.

The core domain must not import or depend on CloudKit.

Conceptually:

```text
Domain
  ↑
Persistence abstraction
  ↑
SwiftData local store
  ↑
CloudKit synchronization
```

CloudKit failures must not make local schedule data unavailable.

---

# 22. Syncable Data

Expected synchronized data:

```text
WorkDay
ShiftDefinition
ScheduleRule
TaskDefinition
AppSettings
```

Local-only/device-specific data:

```text
Notification registrations
Notification request identifiers
Widget timeline state
```

---

# 23. Sync Conflict Policy

Initial policy:

```text
Last modification wins
```

using a reliable `modifiedAt` timestamp.

The conflict policy must be deterministic.

CloudKit conflict handling must not overwrite a newer local WorkDay with an older remote version.

---

# 24. Sync and Historical Snapshot

Cloud synchronization must preserve the WorkDay resolved snapshot.

A synchronized WorkDay includes its resolved:

```text
Start
End
Break Start
Break End
```

Therefore another device displays the same historical schedule.

---

# 25. Data Integrity

Rules:

1. One primary WorkDay per calendar date.
2. Task data must remain independent from shift timing.
3. WorkDay snapshots must remain stable.
4. Deleting a WorkDay must not leave an active reminder.
5. Sync failure must not delete valid local data.
6. Shift configuration changes must not rewrite historical WorkDays.

---

# 26. Testing Architecture

Tests should be organized around domain behavior.

Highest priority:

```text
ShiftResolverTests
WorkDayTests
Reminder scheduling tests
Data integrity tests
```

Widget and CloudKit tests are later-phase integration tests.

---

# 27. Required Shift Tests

At minimum:

```text
C1
C2
C3
C4
C5 normal

C5 day 9
C5 day 10
C5 day 20
C5 day 21

February
December / January year boundary
```

Also verify that the same rule works for leap and non-leap years.

---

# 28. Historical Snapshot Tests

Required:

```text
Create C5 WorkDay on day 15
Verify snapshot = 12:00 → 21:30

Change C5 configuration
Verify old WorkDay remains 12:00 → 21:30

Create/edit future WorkDay
Verify new configuration is applied
```

This is a P0 data-integrity test.

---

# 29. Dependency Direction

Allowed:

```text
UI
 ↓
Application
 ↓
Domain
 ↓
Persistence
```

Domain must not depend on:

```text
SwiftUI
WidgetKit
UserNotifications
CloudKit
```

The domain should remain reusable.

---

# 30. Project Structure

Recommended:

```text
ShiftFlow/
├── App/
├── Domain/
│   ├── Models/
│   ├── Services/
│   └── Rules/
├── Application/
│   ├── UseCases/
│   └── ViewModels/
├── Persistence/
│   ├── SwiftData/
│   └── CloudKit/
├── UI/
│   ├── Calendar/
│   ├── Today/
│   ├── DayDetail/
│   └── Settings/
├── Notifications/
├── Widget/
└── Tests/
```

The exact folder structure may be adjusted by Kiro if the dependency rules remain intact.

---

# 31. Architecture Change Control

Kiro must not make major architecture changes silently.

If implementation reveals a conflict:

```text
Stop implementation
↓
Describe issue
↓
Explain impact
↓
Propose alternatives
↓
Wait for approval
```

Minor implementation details may be chosen by Kiro when they do not alter approved architecture or product behavior.

---

# 32. Architecture Baseline

```text
Version: v0.1.1
Status: Approved after specification review
```

Key decisions:

```text
Central ShiftResolver
WorkDay resolved-time snapshot
Shared domain for Widget
Offline-first local persistence
Rolling 7–14 day notification scheduling
CloudKit as later synchronization layer
```

---

# 33. CloudKit Implementation (TASK-CLOUDKIT-001)

This section documents how the approved CloudKit synchronization layer was
implemented. It refines, but does not change, the approved decisions above.

## SwiftData + CloudKit

CloudKit sync uses Apple's native SwiftData + CloudKit integration via
`ModelConfiguration(cloudKitDatabase: .private(<container>))`. No custom
backend, REST API, or authentication is introduced.

```text
SwiftData local store  (source of truth, offline-first)
        ↓ automatic mirroring
CloudKit private database
        ↓ device-to-device
Other user devices
```

## CloudKit-Compatibility Model Changes

CloudKit does not support:

```text
@Attribute(.unique)
non-optional stored properties without default values
```

Therefore:

- `WorkDayModel.id` no longer uses `@Attribute(.unique)`.
- All non-optional stored properties have default values.
- "One WorkDay per calendar date" is enforced at the service layer
  (`WorkDayService`) and post-sync by `SyncConflictResolver`.

## Offline-First / Fallback

`PersistenceConfiguration.makeContainer(useCloudKit:)` attempts a CloudKit
configuration and falls back to a local-only store if CloudKit is
unavailable (missing entitlement, no account, etc.). The app is fully
usable offline. CloudKit failure never blocks local operations.

## Conflict Strategy

`SyncConflictResolver` (pure domain logic):

```text
Same record (same id):
   last modification wins (modifiedAt), tiebreak by id string.

Date collision (two records, same date):
   keep the most-recently-modified WorkDay,
   remove the duplicate(s),
   NEVER recalculate the winner's snapshot.
```

A WorkDay's resolved snapshot is NEVER recalculated from ShiftDefinition
during sync. Only an explicit shift change (WorkDayService.changeShift)
creates a new snapshot.

## Deletion

SwiftData + CloudKit propagate deletions automatically. A deleted WorkDay
does not resurrect after sync. Reminders are cancelled locally by the
Notifications layer — notification requests are never synced.

## Widget After Sync

After `CloudSyncService.syncDidComplete()`:

```text
Local store updated (by SwiftData)
      ↓
Date-collision integrity check (SyncConflictResolver)
      ↓
WidgetRefreshCoordinator.refresh()  (rebuild snapshot)
      ↓
App Group snapshot updated + WidgetKit reload
```

The Widget App Group JSON snapshot is a derived local artifact and is
NEVER synced via CloudKit.

## Reminders Are Device-Local

`UNUserNotificationCenter` requests are never synchronized. If
ReminderConfiguration is persisted, the preference may sync, but each
device schedules its own local notifications from its local WorkDay
snapshot and permission state.

## Sync Status

`SyncStatus` exposes user-facing states (Synced / Syncing / Waiting /
Unavailable / Account Unavailable) with Vietnamese display text. Raw
CloudKit error codes are never shown. Local data is always usable.

## Data Synced vs Not Synced

```text
Synced:      WorkDay, ShiftDefinition, ScheduleRule, TaskDefinition,
             AppSettings, WorkDay notes, ReminderConfiguration (if persisted)

Not synced:  Notification requests, Widget App Group snapshot,
             Widget timeline entries, temporary UI/navigation state
```

## Migration

Making models CloudKit-compatible (removing `.unique`, adding defaults) is a
forward-compatible model refinement. Local data is not destroyed. Future
schema changes must be documented and use SwiftData migration.

---

End of Architecture Specification.
