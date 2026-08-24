# Implementation Plan: Kiro Spec

**Project:** ShiftFlow
**Version:** v0.1.1
**Status:** Baseline
**Implementation Agent:** Kiro

## Overview

Implement ShiftFlow incrementally as a native iOS shift-management application.

Implementation must follow:

- `.kiro/steering/product.md`
- `.kiro/steering/architecture.md`
- `.kiro/steering/development-rules.md`
- `.kiro/specs/shiftflow/requirements.md`
- `.kiro/specs/shiftflow/design.md`
- `CHANGELOG.md`

Do not implement all phases at once.

The critical path is:

```text
Project Foundation
↓
Shift Domain
↓
ShiftResolver
↓
WorkDay Snapshot
↓
Calendar
↓
Settings
↓
Reminders
↓
Widget
↓
CloudKit
↓
QA
```

## Tasks

### 1. Project Foundation

- [ ] 1.1 Create native SwiftUI iOS project.
- [ ] 1.2 Establish layered project architecture.
- [ ] 1.3 Establish a reusable/shared Domain target or module for App and Widget.
- [ ] 1.4 Configure SwiftData.
- [ ] 1.5 Configure initial test target.

**Priority:** P0

### 2. Shift Domain

- [ ] 2.1 Implement `ShiftDefinition`.
- [ ] 2.2 Implement `ScheduleRule`.
- [ ] 2.3 Implement `ResolvedShift`.
- [ ] 2.4 Implement `ShiftResolver`.
- [ ] 2.5 Implement first-launch seed for C1–C5.
- [ ] 2.6 Ensure seed operation is idempotent.
- [ ] 2.7 Add C1–C5 unit tests.
- [ ] 2.8 Add C5 day 9/10/20/21 boundary tests.
- [ ] 2.9 Add February tests.
- [ ] 2.10 Add December/January year-boundary tests.
- [ ] 2.11 Add leap/non-leap year tests.

**Requirements:** FR-SHIFT-001 through FR-SHIFT-010, FR-RESOLVE-001 through FR-RESOLVE-003

**Priority:** P0

### 3. WorkDay Data and Historical Snapshot

- [ ] 3.1 Implement `WorkDay`.
- [ ] 3.2 Implement WorkDay CRUD.
- [ ] 3.3 Enforce one primary WorkDay per date.
- [ ] 3.4 Store resolved start/end/break snapshot on WorkDay.
- [ ] 3.5 Recalculate snapshot when creating a WorkDay.
- [ ] 3.6 Recalculate snapshot when the WorkDay shift changes.
- [ ] 3.7 Do not silently recalculate historical WorkDays when global shift configuration changes.
- [ ] 3.8 Add WorkDay persistence tests.
- [ ] 3.9 Add historical snapshot regression tests.

**Requirements:** FR-WD-001 through FR-WD-003, FR-SHIFT-010, FR-DATA-001 through FR-DATA-004

**Priority:** P0

### 4. Tasks

- [ ] 4.1 Implement `TaskDefinition`.
- [ ] 4.2 Seed MW as the initial task.
- [ ] 4.3 Attach tasks to WorkDay.
- [ ] 4.4 Remove tasks from WorkDay.
- [ ] 4.5 Support multiple tasks.
- [ ] 4.6 Add task independence tests.

**Dependencies:** 4.6 depends on 4.3 and 4.4.

**Acceptance:** Adding/removing MW never changes Start, End, or Break.

**Requirements:** FR-TASK-001 through FR-TASK-005

**Priority:** P0/P1

### 5. Notes

- [ ] 5.1 Add optional WorkDay note.
- [ ] 5.2 Add/edit/delete note.
- [ ] 5.3 Add note indicator support.
- [ ] 5.4 Add note persistence tests.

**Requirements:** FR-NOTE-001 through FR-NOTE-004

**Priority:** P0/P1

### 6. Calendar

- [ ] 6.1 Create Calendar screen.
- [ ] 6.2 Implement Month view as default.
- [ ] 6.3 Display date and shift code.
- [ ] 6.4 Display task and note indicators.
- [ ] 6.5 Implement date selection.
- [ ] 6.6 Implement Day Detail Sheet.
- [ ] 6.7 Implement shift selection in Day Detail.
- [ ] 6.8 Display WorkDay resolved snapshot.
- [ ] 6.9 Implement Week view.
- [ ] 6.10 Implement 3 Days view.
- [ ] 6.11 Implement Today view.
- [ ] 6.12 Implement Previous/Next navigation.
- [ ] 6.13 Implement Today navigation.
- [ ] 6.14 Implement next scheduled WorkDay query for Today view.
- [ ] 6.15 Implement delete confirmation and unsaved-changes handling.

**Requirements:** FR-CAL-001 through FR-CAL-006, FR-DAY-001 through FR-DAY-004, Req 54 (Color Independence)

**Priority:** P0/P1

**Accessibility Constraint (P0 — applies to 6.2, 6.3, 6.9, 6.10, 6.11):**

WHEN a WorkDay is displayed in any calendar view, THE SYSTEM SHALL display the shift code/text in addition to any visual color. WHEN the shift color cannot be perceived, THE SYSTEM SHALL still allow the user to identify the shift from visible text or accessibility labels. Shift identity must never be communicated by color alone.

**Task 6.15 Details:**

- Deleting a WorkDay requires confirmation before execution.
- Canceling the confirmation preserves the WorkDay unchanged.
- Unsaved Day Detail changes must not be silently discarded.
- If the user attempts to dismiss the Day Detail sheet with unsaved changes, the system must present a confirmation (Keep Editing / Discard).
- Saving changes persists them.
- Canceling/discarding changes restores the previously persisted state.

**Dependencies:** 6.15 depends on 6.6 (Day Detail Sheet).

**Priority for 6.15:** P1

### 7. Settings

- [ ] 7.1 Create Settings screen.
- [ ] 7.2 Create Shift Configuration screen.
- [ ] 7.3 Allow editing C1–C5.
- [ ] 7.4 Create Special Schedule editor.
- [ ] 7.5 Persist configuration changes.
- [ ] 7.6 Verify configuration changes do not rewrite existing WorkDay snapshots.
- [ ] 7.7 Create Task Configuration screen.

**Requirements:** FR-SET-001 through FR-SET-004, FR-SHIFT-009, FR-SHIFT-010

**Priority:** P0/P1

### 8. Notifications

- [ ] 8.1 Implement `NotificationService`.
- [ ] 8.2 Request notification permission and handle denied state.
- [ ] 8.3 Implement reminder offsets: 30m, 1h, 2h, 24h.
- [ ] 8.4 Define 24h-before semantics as exactly 24 hours before resolved shift start.
- [ ] 8.5 Schedule notifications from WorkDay resolved start time.
- [ ] 8.6 Implement deterministic notification identifiers.
- [ ] 8.7 Implement rolling 7–14 day scheduling window.
- [ ] 8.8 Reconcile/cancel stale ShiftFlow notifications.
- [ ] 8.9 Rebuild reminders when WorkDay changes.
- [ ] 8.10 Cancel reminders when WorkDay is deleted.
- [ ] 8.11 Add reminder lifecycle tests.
- [ ] 8.12 Add test for early-morning shift + 24h reminder.

**Requirements:** FR-REM-001 through FR-REM-005, Req 65 (Notification Permission Handling)

**Priority:** P1

**Task 8.2 Acceptance Criteria:**

WHEN notification permission has not been determined, THE SYSTEM SHALL request notification authorization at an appropriate point (e.g., when the user first enables a reminder). WHEN notification permission is denied, THE SYSTEM SHALL display a message explaining that reminders require notification permission. WHEN notification permission is denied, THE SYSTEM SHALL provide a route for the user to open system Settings and enable notifications. The application must not repeatedly prompt the user after the system has denied permission.

### 9. Widget

- [ ] 9.1 Create WidgetKit extension.
- [ ] 9.2 Connect Widget to shared Domain module.
- [ ] 9.3 Implement Small widget.
- [ ] 9.4 Implement Medium widget.
- [ ] 9.5 Implement Large widget.
- [ ] 9.6 Display current/upcoming schedule.
- [ ] 9.7 Request WidgetKit refresh after relevant schedule changes.
- [ ] 9.8 Add Widget timeline generation tests where practical.

**Requirements:** FR-WIDGET-001 through FR-WIDGET-004

**Priority:** P2

### 10. CloudKit Sync

- [ ] 10.1 Configure CloudKit.
- [ ] 10.2 Define syncable records.
- [ ] 10.3 Synchronize WorkDay including resolved snapshot fields.
- [ ] 10.4 Synchronize ShiftDefinition and ScheduleRule.
- [ ] 10.5 Synchronize TaskDefinition and AppSettings.
- [ ] 10.6 Implement multi-device synchronization.
- [ ] 10.7 Implement offline-first sync behavior.
- [ ] 10.8 Implement deterministic last-modification-wins conflict handling.
- [ ] 10.9 Verify sync failure never deletes valid local data.
- [ ] 10.10 Add sync/conflict tests.

**Requirements:** FR-SYNC-001 through FR-SYNC-004, FR-OFFLINE-001 through FR-OFFLINE-003

**Priority:** P2

### 11. Integration

- [ ] 11.1 Verify Calendar uses WorkDay resolved snapshot / approved domain logic.
- [ ] 11.2 Verify Today uses the same schedule source.
- [ ] 11.3 Verify Reminder uses WorkDay resolved schedule.
- [ ] 11.4 Verify Widget uses shared domain logic and consistent schedule data.
- [ ] 11.5 Verify shift editing updates the WorkDay snapshot.
- [ ] 11.6 Verify shift configuration changes do not rewrite historical WorkDays.
- [ ] 11.7 Verify deleting WorkDay cancels its reminder.
- [ ] 11.8 Verify MW never changes resolved working time.
- [ ] 11.9 Verify offline-first behavior.

**Priority:** P0/P1/P2

**Task 11.9 Acceptance Criteria:**

WHEN the device has no network connectivity, THE SYSTEM SHALL allow the user to view existing locally stored WorkDays. WHEN the device has no network connectivity, THE SYSTEM SHALL allow supported local WorkDay, Task, Note, and Shift configuration operations. WHEN the device reconnects, THE SYSTEM SHALL allow later synchronization according to the approved CloudKit architecture (P2).

**Priority for 11.9:** P1

### 12. Accessibility and UI Polish

- [ ] 12.1 Verify color is not the only shift identifier.
- [ ] 12.2 Add accessibility labels.
- [ ] 12.3 Verify VoiceOver behavior.
- [ ] 12.4 Review typography and spacing.
- [ ] 12.5 Review empty states.
- [ ] 12.6 Review error states.
- [ ] 12.7 Verify common iPhone screen sizes.

**Requirements:** FR-A11Y-001, FR-A11Y-002, FR-PERF-001, FR-PERF-002

**Priority:** P2

### 13. Final QA

- [ ] 13.1 Full regression test.
- [ ] 13.2 Verify C1–C5.
- [ ] 13.3 Verify C5 days 9/10/20/21.
- [ ] 13.4 Verify C5 February.
- [ ] 13.5 Verify year boundary.
- [ ] 13.6 Verify historical snapshot protection.
- [ ] 13.7 Verify Month/Week/3 Days/Today.
- [ ] 13.8 Verify Tasks and Notes.
- [ ] 13.9 Verify Reminder lifecycle.
- [ ] 13.10 Verify Widget.
- [ ] 13.11 Verify offline behavior.
- [ ] 13.12 Verify CloudKit sync.
- [ ] 13.13 Verify data integrity.
- [ ] 13.14 Build release configuration.
- [ ] 13.15 Update CHANGELOG.md.

**Priority:** P0/P1/P2

## Notes

### Critical Business Rules

```text
C5 normal:
11:30 → 21:00
Break 16:30 → 17:30

C5 day 10–20:
12:00 → 21:30
Break 16:30 → 17:30
```

Boundary:

```text
Day 9  → normal
Day 10 → special
Day 20 → special
Day 21 → normal
```

### Historical Snapshot Rule

```text
Create/Edit WorkDay
      ↓
ShiftResolver
      ↓
ResolvedShift
      ↓
Snapshot into WorkDay
```

Changing global ShiftDefinition must not silently rewrite existing WorkDay snapshots.

### OFF Rule

```text
WorkDay exists → scheduled work
No WorkDay → no scheduled shift
```

The UI may display `OFF`; OFF is not a persistent ShiftDefinition.

### Reminder Rule

Use a rolling scheduling window of approximately 7–14 days.

`24 hours before` means exactly 24 hours before resolved shift start.

### Implementation Rules

1. Read all steering documents before implementation.
2. Do not hard-code shift schedules inside SwiftUI views.
3. Do not duplicate C5 logic in Calendar, Reminder, or Widget.
4. All schedule resolution must use the approved domain logic.
5. Tasks must remain separate from shift timing.
6. MW must never modify Start, End, or Break.
7. Historical WorkDay snapshots must be preserved.
8. Do not add features outside approved scope.
9. Do not make major architecture changes without approval.
10. Run relevant tests before marking a task complete.
11. Update CHANGELOG.md for meaningful completed changes.
12. Do not mark a task complete when acceptance criteria are not satisfied.

### Task Completion

A task is complete only when:

```text
Implementation complete
Acceptance criteria pass
Relevant tests pass
No critical regression
Documentation updated where required
CHANGELOG updated where required
```

### Change Control

If implementation requires a product or architecture change:

```text
Stop
↓
Explain issue
↓
Explain impact
↓
Propose solution
↓
Wait for approval
```

Do not silently change approved specifications.

## Task Dependency Graph

```text
Foundation
    ↓
Shift Domain
    ↓
WorkDay + Historical Snapshot
    ↓
Tasks + Notes
    ↓
Calendar
    ↓
Settings
    ↓
Notifications
    ↓
Widget
    ↓
CloudKit
    ↓
Integration
    ↓
Polish
    ↓
QA
```

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4", "1.5"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.8", "2.9", "2.10", "2.11"] },
    { "id": 2, "tasks": ["3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8", "3.9"] },
    { "id": 3, "tasks": ["4.1", "4.2", "4.3", "4.4", "4.5", "4.6", "5.1", "5.2", "5.3", "5.4"] },
    { "id": 4, "tasks": ["6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "6.10", "6.11", "6.12", "6.13", "6.14", "6.15"] },
    { "id": 5, "tasks": ["7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7"] },
    { "id": 6, "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "8.10", "8.11", "8.12"] },
    { "id": 7, "tasks": ["9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8"] },
    { "id": 8, "tasks": ["10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "10.10"] },
    { "id": 9, "tasks": ["11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9"] },
    { "id": 10, "tasks": ["12.1", "12.2", "12.3", "12.4", "12.5", "12.6", "12.7"] },
    { "id": 11, "tasks": ["13.1", "13.2", "13.3", "13.4", "13.5", "13.6", "13.7", "13.8", "13.9", "13.10", "13.11", "13.12", "13.13", "13.14", "13.15"] }
  ]
}
```

**Version:** v0.1.1
**Status:** Baseline
**End of Implementation Plan**
