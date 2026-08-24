# Requirements

**Project:** ShiftFlow  
**Version:** v0.1.1  
**Status:** Baseline  
**Product:** ShiftFlow  
**Related Documents:**
- `.kiro/steering/product.md`
- `.kiro/steering/architecture.md`
- `.kiro/steering/development-rules.md`
- `CHANGELOG.md`

---

## Priority Legend

- **P0** = Core MVP requirement
- **P1** = Important MVP requirement
- **P2** = Post-MVP / later phase

---

### Requirement 1: Create Work Day

**Priority:** P0

The user must be able to create a work-day record for a specific date, assigning a shift that automatically resolves working hours.

#### Acceptance Criteria

- WHEN the user selects a date and assigns a shift, THE SYSTEM SHALL persist a WorkDay record containing the date, shift reference, resolved start time, resolved end time, resolved break start, and resolved break end.
- WHEN a WorkDay is created, THE SYSTEM SHALL display it in the calendar view.
- WHEN a WorkDay is created, THE SYSTEM SHALL automatically resolve the shift schedule using the central ShiftResolver without requiring the user to manually enter working hours.

---

### Requirement 2: Edit Work Day

**Priority:** P0

The user must be able to edit an existing WorkDay, including shift, tasks, note, and reminder settings.

#### Acceptance Criteria

- WHEN the user changes the shift on an existing WorkDay, THE SYSTEM SHALL recalculate the resolved start, end, break start, and break end using the ShiftResolver and persist the updated snapshot.
- WHEN the user edits a WorkDay's tasks or note, THE SYSTEM SHALL persist the changes without modifying the resolved working times.
- WHEN the user saves changes to a WorkDay, THE SYSTEM SHALL reflect the updated data in all calendar views, the Widget, and any associated reminder.

---

### Requirement 3: Delete Work Day

**Priority:** P0

The user must be able to remove a scheduled WorkDay.

#### Acceptance Criteria

- WHEN the user deletes a WorkDay, THE SYSTEM SHALL remove the record from persistence and from all calendar views.
- WHEN the user deletes a WorkDay, THE SYSTEM SHALL cancel any associated local notification reminder.
- WHEN the user deletes a WorkDay, THE SYSTEM SHALL NOT leave stale schedule data visible in the calendar or widget.

---

### Requirement 4: Support Five Shifts

**Priority:** P0

The application must support five configurable shift definitions: C1, C2, C3, C4, C5.

#### Acceptance Criteria

- WHEN the application launches for the first time, THE SYSTEM SHALL seed five default shift definitions (C1, C2, C3, C4, C5) if no shift definitions exist.
- THE SYSTEM SHALL NOT create duplicate shift definitions if they already exist (idempotent seed).

---

### Requirement 5: C1 Schedule

**Priority:** P0

C1 default schedule: 07:00–16:30, Break 11:00–12:00.

#### Acceptance Criteria

- WHEN the user selects shift C1 for a WorkDay, THE SYSTEM SHALL resolve the WorkDay to start 07:00, end 16:30, break start 11:00, break end 12:00.

---

### Requirement 6: C2 Schedule

**Priority:** P0

C2 default schedule: 07:30–17:00, Break 11:30–12:30.

#### Acceptance Criteria

- WHEN the user selects shift C2 for a WorkDay, THE SYSTEM SHALL resolve the WorkDay to start 07:30, end 17:00, break start 11:30, break end 12:30.

---

### Requirement 7: C3 Schedule

**Priority:** P0

C3 default schedule: 08:00–17:30, Break 12:00–13:00.

#### Acceptance Criteria

- WHEN the user selects shift C3 for a WorkDay, THE SYSTEM SHALL resolve the WorkDay to start 08:00, end 17:30, break start 12:00, break end 13:00.

---

### Requirement 8: C4 Schedule

**Priority:** P0

C4 default schedule: 08:30–18:00, Break 12:30–13:30.

#### Acceptance Criteria

- WHEN the user selects shift C4 for a WorkDay, THE SYSTEM SHALL resolve the WorkDay to start 08:30, end 18:00, break start 12:30, break end 13:30.

---

### Requirement 9: C5 Normal Schedule

**Priority:** P0

C5 default schedule outside the special date range: 11:30–21:00, Break 16:30–17:30.

#### Acceptance Criteria

- WHEN the user selects shift C5 for a WorkDay on a date where the day-of-month is less than 10 or greater than 20, THE SYSTEM SHALL resolve the WorkDay to start 11:30, end 21:00, break start 16:30, break end 17:30.
- WHEN the user selects shift C5 for a WorkDay on day 9 of any month, THE SYSTEM SHALL resolve to the normal schedule (11:30–21:00).
- WHEN the user selects shift C5 for a WorkDay on day 21 of any month, THE SYSTEM SHALL resolve to the normal schedule (11:30–21:00).

---

### Requirement 10: C5 Special Schedule

**Priority:** P0

For calendar days 10 through 20 inclusive of any month, C5 resolves to: 12:00–21:30, Break 16:30–17:30.

#### Acceptance Criteria

- IF the selected date is between day 10 and day 20 inclusive, AND the selected shift is C5, THEN THE SYSTEM SHALL resolve C5 to start 12:00, end 21:30, break start 16:30, break end 17:30.
- WHEN the user selects C5 on day 10 of any month, THE SYSTEM SHALL resolve to the special schedule (12:00–21:30).
- WHEN the user selects C5 on day 20 of any month, THE SYSTEM SHALL resolve to the special schedule (12:00–21:30).
- THE SYSTEM SHALL apply the C5 special rule independently for every month regardless of year.
- THE SYSTEM SHALL correctly resolve C5 in February (28 or 29 days) and at year boundaries (December/January).

---

### Requirement 11: Automatic Shift Resolution

**Priority:** P0

The user selects only a date and shift. The application determines start, end, break start, and break end automatically.

#### Acceptance Criteria

- WHEN the user assigns a shift to a date, THE SYSTEM SHALL invoke the central ShiftResolver to determine working times without requiring manual time entry from the user.
- THE SYSTEM SHALL NOT require the user to manually enter standard working hours for any predefined shift.

---

### Requirement 12: Configurable Shift

**Priority:** P0

The user must be able to edit shift configuration (start time, end time, break start, break end, schedule rules) from Settings.

#### Acceptance Criteria

- WHEN the user modifies a shift's start time, end time, break start, or break end in Settings, THE SYSTEM SHALL persist the new configuration.
- WHEN the user creates a new WorkDay after a configuration change, THE SYSTEM SHALL use the updated configuration for resolution.
- WHEN the user modifies shift configuration, THE SYSTEM SHALL NOT modify the resolved snapshot of any existing WorkDay.

---

### Requirement 13: Historical Configuration Protection

**Priority:** P1

Future configuration changes must not incorrectly alter historical schedule meaning.

#### Acceptance Criteria

- WHEN the user changes a global shift configuration, THE SYSTEM SHALL NOT modify the resolved snapshot of existing WorkDays.
- WHEN the user changes C5 normal schedule from 11:30–21:00 to 13:00–22:00, THE SYSTEM SHALL preserve all existing WorkDay snapshots that were resolved under the previous configuration.
- WHEN the user explicitly edits an individual WorkDay's shift assignment, THE SYSTEM SHALL recalculate the snapshot using the current configuration.

---

### Requirement 14: Central Resolver

**Priority:** P0

All working-time calculations must use a single central schedule-resolution component (ShiftResolver).

#### Acceptance Criteria

- THE SYSTEM SHALL use one ShiftResolver component for all schedule resolution across Month view, Week view, 3 Days view, Today view, Day Detail, Reminder scheduling, and Widget data.
- THE SYSTEM SHALL NOT contain independent shift calculation logic in any UI component, notification service, or widget target.

---

### Requirement 15: Consistent Schedule Display

**Priority:** P0

The same resolved schedule must be used by all views and features.

#### Acceptance Criteria

- WHEN the same WorkDay is displayed in Month view, Week view, 3 Days view, Today view, Day Detail, and Widget, THE SYSTEM SHALL show identical resolved working times.
- IF any view displays different resolved times for the same WorkDay, THEN it SHALL be treated as a defect.

---

### Requirement 16: Deterministic Calculation

**Priority:** P0

Given the same date, shift, and configuration, the resolver must return the same result every time.

#### Acceptance Criteria

- WHEN the ShiftResolver is invoked with the same date, shift, and configuration multiple times, THE SYSTEM SHALL return identical results.
- THE SYSTEM SHALL NOT depend on network state, CloudKit availability, UI state, or notification state for schedule resolution.

---

### Requirement 17: Month View

**Priority:** P0

The application must provide a monthly calendar displaying date, shift code, task indicator, and note indicator for each day.

#### Acceptance Criteria

- WHEN the user opens the Calendar screen, THE SYSTEM SHALL display the Month view as the default view.
- WHEN a day has a WorkDay record, THE SYSTEM SHALL display the shift code, a task indicator (if tasks exist), and a note indicator (if a note exists).
- THE SYSTEM SHALL NOT display full working hours in month-view day cells.

---

### Requirement 18: Week View

**Priority:** P1

The application must provide a seven-day view showing date, shift, working hours, tasks, and note indicator.

#### Acceptance Criteria

- WHEN the user switches to Week view, THE SYSTEM SHALL display seven consecutive days with shift code and resolved working hours for each day that has a WorkDay.

---

### Requirement 19: Three Day View

**Priority:** P1

The application must provide a view showing today, tomorrow, and the following day with shift, time, break, tasks, and notes.

#### Acceptance Criteria

- WHEN the user switches to 3 Days view, THE SYSTEM SHALL display today, tomorrow, and the day after with their respective shift, start time, end time, break, tasks, and notes.

---

### Requirement 20: Today View

**Priority:** P1

Today must clearly show today's shift, working time, break, tasks, note, and next scheduled shift.

#### Acceptance Criteria

- WHEN the user opens the Today view, THE SYSTEM SHALL display the current date's shift, resolved start time, end time, break start, break end, tasks, and note.
- WHEN the user views the Today screen, THE SYSTEM SHALL display the next scheduled WorkDay (next shift query) below the current day's information.
- IF no future WorkDay exists, THEN THE SYSTEM SHALL display "No upcoming shift scheduled."

---

### Requirement 21: Navigate Dates

**Priority:** P0

The user must be able to navigate between dates/months appropriate to the current calendar view.

#### Acceptance Criteria

- WHEN the user taps the forward navigation control in Month view, THE SYSTEM SHALL display the next month.
- WHEN the user taps the backward navigation control in Month view, THE SYSTEM SHALL display the previous month.

---

### Requirement 22: Select Day

**Priority:** P0

Selecting a day must open its detail/edit interface.

#### Acceptance Criteria

- WHEN the user taps a day in the calendar, THE SYSTEM SHALL present the Day Detail sheet for that date.

---

### Requirement 23: Task Concept

**Priority:** P0

A task is additional work attached to a WorkDay. A task is NOT a shift and must never contain working-hour calculation logic.

#### Acceptance Criteria

- WHEN a task is attached to a WorkDay, THE SYSTEM SHALL store it as a separate entity from the shift definition.
- THE SYSTEM SHALL NOT include any shift timing logic within the task model or task service.

---

### Requirement 24: MW Task

**Priority:** P0

The application must support the MW task. The user must be able to attach or remove MW from a WorkDay.

#### Acceptance Criteria

- WHEN the user assigns MW to a WorkDay, THE SYSTEM SHALL preserve the WorkDay's resolved start, end, break start, and break end times unchanged.
- WHEN the user removes MW from a WorkDay, THE SYSTEM SHALL preserve the WorkDay's resolved start, end, break start, and break end times unchanged.
- THE SYSTEM SHALL NOT modify any resolved time fields when MW is added or removed.

---

### Requirement 25: Multiple Tasks

**Priority:** P1

The data model should allow more than one task on a WorkDay.

#### Acceptance Criteria

- WHEN the user adds multiple tasks (e.g., MW, Zalo) to a WorkDay, THE SYSTEM SHALL persist all assigned tasks and display them in the Day Detail view.

---

### Requirement 26: Tasks Do Not Change Shift

**Priority:** P0

Adding or removing any task must not modify start, end, or break times.

#### Acceptance Criteria

- WHEN the user adds any task to a WorkDay, THE SYSTEM SHALL NOT modify the WorkDay's resolved start time, end time, break start, or break end.
- WHEN the user removes any task from a WorkDay, THE SYSTEM SHALL NOT modify the WorkDay's resolved start time, end time, break start, or break end.

---

### Requirement 27: Task Configuration

**Priority:** P1

The application should support configurable task definitions from Settings.

#### Acceptance Criteria

- WHEN the user opens Task Configuration in Settings, THE SYSTEM SHALL display the list of available task definitions.
- WHEN the user adds a new task definition, THE SYSTEM SHALL make it available for assignment to WorkDays.

---

### Requirement 28: Add Note

**Priority:** P0

The user can attach an optional plain-text note to a WorkDay.

#### Acceptance Criteria

- WHEN the user enters text in the note field and saves the WorkDay, THE SYSTEM SHALL persist the note text associated with that WorkDay.
- THE SYSTEM SHALL NOT allow the note content to influence ShiftResolver calculations, reminder timing, or shift duration.

---

### Requirement 29: Edit Note

**Priority:** P0

The user can modify an existing note.

#### Acceptance Criteria

- WHEN the user modifies the note text on an existing WorkDay and saves, THE SYSTEM SHALL persist the updated note text without modifying any other WorkDay fields.

---

### Requirement 30: Delete Note

**Priority:** P0

The user can remove a note from a WorkDay.

#### Acceptance Criteria

- WHEN the user clears the note field and saves the WorkDay, THE SYSTEM SHALL remove the note text from persistence.
- THE SYSTEM SHALL NOT modify resolved times, tasks, or reminder configuration when a note is deleted.

---

### Requirement 31: Note Indicator

**Priority:** P1

Calendar views should provide a compact visual indicator when a day contains a note.

#### Acceptance Criteria

- WHEN a WorkDay has a non-empty note, THE SYSTEM SHALL display a compact note indicator in the Month view day cell.
- THE SYSTEM SHALL NOT display the full note text in the Month view.

---

### Requirement 32: Day Detail Interface

**Priority:** P0

Selecting a day should open an iOS-native sheet displaying date, shift, resolved working time, break, tasks, note, and reminder configuration.

#### Acceptance Criteria

- WHEN the user selects a day with an existing WorkDay, THE SYSTEM SHALL present a sheet displaying all WorkDay information (date, shift code, resolved start, resolved end, break start, break end, tasks, note, reminder status).
- WHEN the user selects a day without a WorkDay, THE SYSTEM SHALL present the sheet with an option to add a shift.

---

### Requirement 33: Edit Shift from Day Detail

**Priority:** P0

The user can change the shift from the Day Detail interface. The application must immediately resolve the new working schedule.

#### Acceptance Criteria

- WHEN the user changes the shift selection in the Day Detail sheet, THE SYSTEM SHALL immediately invoke the ShiftResolver and display the updated resolved times before the user saves.

---

### Requirement 34: Edit Tasks from Day Detail

**Priority:** P0

The user can add/remove tasks from the Day Detail interface.

#### Acceptance Criteria

- WHEN the user adds or removes a task in the Day Detail sheet, THE SYSTEM SHALL update the task list without modifying the resolved working times displayed.

---

### Requirement 35: Edit Note from Day Detail

**Priority:** P0

The user can edit the day's note from the Day Detail interface.

#### Acceptance Criteria

- WHEN the user modifies the note in the Day Detail sheet and saves, THE SYSTEM SHALL persist the updated note.

---

### Requirement 36: Enable Reminder

**Priority:** P1

The user can enable or disable shift reminders per WorkDay.

#### Acceptance Criteria

- WHEN the user enables a reminder for a WorkDay, THE SYSTEM SHALL schedule a local notification based on the resolved shift start time and selected offset.
- WHEN the user disables a reminder for a WorkDay, THE SYSTEM SHALL cancel the associated local notification.

---

### Requirement 37: Reminder Offset

**Priority:** P1

Supported reminder offsets: 30 minutes, 1 hour, 2 hours, 24 hours (exactly 24 hours before resolved shift start).

#### Acceptance Criteria

- WHEN the user selects "30 minutes before," THE SYSTEM SHALL schedule the notification exactly 30 minutes before the resolved shift start time.
- WHEN the user selects "1 hour before," THE SYSTEM SHALL schedule the notification exactly 1 hour before the resolved shift start time.
- WHEN the user selects "2 hours before," THE SYSTEM SHALL schedule the notification exactly 2 hours before the resolved shift start time.
- WHEN the user selects "24 hours before," THE SYSTEM SHALL schedule the notification exactly 24 hours before the resolved shift start time.

---

### Requirement 38: Reminder Uses Resolved Shift

**Priority:** P0

Reminder time must be calculated from the resolved shift start time stored in the WorkDay snapshot.

#### Acceptance Criteria

- WHEN a reminder is scheduled for C5 on day 15 with a 2-hour offset, THE SYSTEM SHALL schedule the notification at 10:00 (12:00 start minus 2 hours).
- THE SYSTEM SHALL NOT independently calculate shift times for reminder scheduling; it must use the WorkDay's resolved snapshot.

---

### Requirement 39: Update Reminder on Shift Change

**Priority:** P0

When a WorkDay's shift changes, the system must cancel the old reminder and create a new one based on the updated resolved schedule.

#### Acceptance Criteria

- WHEN the user changes a WorkDay's shift and saves, THE SYSTEM SHALL cancel the previous notification identifier and schedule a new notification based on the newly resolved shift start time.

---

### Requirement 40: Delete Reminder on WorkDay Deletion

**Priority:** P0

When a WorkDay is deleted, its associated local reminder must be cancelled.

#### Acceptance Criteria

- WHEN a WorkDay is deleted, THE SYSTEM SHALL cancel the local notification identified by the deterministic reminder identifier for that WorkDay.
- THE SYSTEM SHALL NOT leave stale notifications after WorkDay deletion.

---

### Requirement 41: Rolling Notification Window

**Priority:** P1

The system must use a rolling scheduling window of approximately 7–14 days for local notifications due to iOS system limits.

#### Acceptance Criteria

- WHEN the notification service schedules reminders, THE SYSTEM SHALL schedule only reminders for WorkDays within approximately the next 7–14 days.
- THE SYSTEM SHALL periodically reconcile and reschedule reminders as the window advances.
- THE SYSTEM SHALL remove stale ShiftFlow notifications that are no longer within the rolling window.

---

### Requirement 42: Home Screen Widget

**Priority:** P2

Provide an iOS Home Screen Widget in small, medium, and large sizes.

#### Acceptance Criteria

- WHEN the user adds a ShiftFlow widget to the Home Screen, THE SYSTEM SHALL display current and/or upcoming shift information.
- THE SYSTEM SHALL use the same ShiftFlowDomain resolution logic as the main application.
- THE SYSTEM SHALL NOT implement independent shift-resolution logic in the Widget target.

---

### Requirement 43: Widget Refresh

**Priority:** P2

When schedule data changes, the application should request a WidgetKit refresh.

#### Acceptance Criteria

- WHEN a WorkDay is created, edited, or deleted, THE SYSTEM SHALL request a WidgetKit timeline reload.
- THE SYSTEM SHALL respect WidgetKit system-controlled refresh timing and SHALL NOT assume immediate real-time widget updates.

---

### Requirement 44: Settings Screen

**Priority:** P0

The application must provide a Settings screen with access to shift configuration, task configuration, notification settings, and sync status.

#### Acceptance Criteria

- WHEN the user navigates to Settings, THE SYSTEM SHALL display sections for Schedule (Shift Configuration, Task Configuration), Notifications, Sync, and About.

---

### Requirement 45: Shift Configuration in Settings

**Priority:** P0

Settings must provide access to edit all five shift definitions (C1–C5) including start time, end time, break start, break end, and schedule rules.

#### Acceptance Criteria

- WHEN the user opens Shift Configuration, THE SYSTEM SHALL display all five shift definitions with their current times.
- WHEN the user modifies a shift definition and saves, THE SYSTEM SHALL persist the updated configuration for use in future WorkDay creation.

---

### Requirement 46: Schedule Rules Configuration

**Priority:** P0

The user must be able to configure special schedule rules (e.g., C5 Day 10–20).

#### Acceptance Criteria

- WHEN the user edits the C5 special schedule rule, THE SYSTEM SHALL allow modification of the start day, end day, start time, end time, break start, and break end.
- WHEN the user saves a schedule rule change, THE SYSTEM SHALL apply the new rule to future WorkDay resolutions only.

---

### Requirement 47: Offline Calendar

**Priority:** P0

The user must be able to view schedules without Internet access.

#### Acceptance Criteria

- WHEN the device has no Internet connectivity, THE SYSTEM SHALL display all locally persisted WorkDay data in the calendar without error.

---

### Requirement 48: Offline Editing

**Priority:** P0

The user must be able to create, edit, and delete WorkDays, add/remove tasks, and edit notes while offline.

#### Acceptance Criteria

- WHEN the device is offline and the user creates, edits, or deletes a WorkDay, THE SYSTEM SHALL persist the change locally and reflect it in the calendar immediately.

---

### Requirement 49: Sync Later

**Priority:** P1

Local changes should synchronize when connectivity becomes available.

#### Acceptance Criteria

- WHEN Internet connectivity is restored after offline edits, THE SYSTEM SHALL synchronize local changes to iCloud.

---

### Requirement 50: iCloud Sync

**Priority:** P2

The application should synchronize personal schedule data using CloudKit.

#### Acceptance Criteria

- WHEN CloudKit is available and the user has iCloud enabled, THE SYSTEM SHALL synchronize WorkDay, ShiftDefinition, ScheduleRule, TaskDefinition, and AppSettings data across the user's Apple devices.
- THE SYSTEM SHALL NOT synchronize local notification registrations via CloudKit.

---

### Requirement 51: Sync Failure Resilience

**Priority:** P0

The application must remain fully usable if CloudKit is temporarily unavailable.

#### Acceptance Criteria

- WHEN CloudKit is unavailable, THE SYSTEM SHALL continue to operate using local data without displaying blocking errors.
- THE SYSTEM SHALL NOT delete valid local data due to a sync failure.

---

### Requirement 52: No Duplicate WorkDay

**Priority:** P0

For a given calendar date, the application should have at most one primary WorkDay record.

#### Acceptance Criteria

- WHEN the user attempts to create a WorkDay for a date that already has one, THE SYSTEM SHALL present the existing WorkDay for editing rather than creating a duplicate.

---

### Requirement 53: OFF State

**Priority:** P0

OFF means no WorkDay exists for that date. OFF is NOT a persistent ShiftDefinition.

#### Acceptance Criteria

- WHEN no WorkDay record exists for a date, THE SYSTEM SHALL display that date as OFF (no scheduled work) in the calendar.
- THE SYSTEM SHALL NOT store a persistent "OFF" ShiftDefinition in the database.
- WHEN the user deletes a WorkDay, THE SYSTEM SHALL treat that date as OFF without creating any replacement record.

---

### Requirement 54: Color Independence

**Priority:** P0

Shift meaning must not rely only on color. The shift code must remain visible.

#### Acceptance Criteria

- WHEN a shift is displayed in any view, THE SYSTEM SHALL always show the shift code text (C1, C2, C3, C4, C5) regardless of color.
- THE SYSTEM SHALL remain understandable for users with color-vision deficiencies.

---

### Requirement 55: Accessibility Labels

**Priority:** P1

Interactive controls must have meaningful accessibility labels.

#### Acceptance Criteria

- WHEN VoiceOver is active, THE SYSTEM SHALL provide descriptive accessibility labels for all interactive controls including calendar day cells, shift selectors, task toggles, and navigation buttons.

---

### Requirement 56: User-Friendly Errors

**Priority:** P0

Errors visible to users should be understandable and actionable.

#### Acceptance Criteria

- WHEN an error occurs during save, THE SYSTEM SHALL display a concise, non-technical message with a suggested action (e.g., "Unable to save changes. Please try again.").
- THE SYSTEM SHALL NOT expose raw technical error messages or stack traces in the UI.

---

### Requirement 57: Data Safety on Sync Failure

**Priority:** P0

A failed cloud sync must not delete valid local schedule data.

#### Acceptance Criteria

- WHEN a CloudKit sync operation fails, THE SYSTEM SHALL preserve all local WorkDay, ShiftDefinition, and ScheduleRule data intact.

---

### Requirement 58: Calendar Responsiveness

**Priority:** P1

Calendar navigation and day selection should remain responsive.

#### Acceptance Criteria

- WHEN the user navigates between months or selects a day, THE SYSTEM SHALL respond within a perceptible instant (target < 100ms for UI response).

---

### Requirement 59: Efficient Data Access

**Priority:** P1

Avoid unnecessary repeated database operations while rendering calendar views.

#### Acceptance Criteria

- WHEN rendering a month view, THE SYSTEM SHALL fetch WorkDay data efficiently (e.g., single query for the visible date range) rather than individual queries per day cell.

---

### Requirement 60: Shift Resolver Tests

**Priority:** P0

Tests must cover C1, C2, C3, C4, C5 normal, C5 day 9, C5 day 10, C5 day 20, C5 day 21, February boundaries, and year boundaries.

#### Acceptance Criteria

- WHEN the test suite runs, THE SYSTEM SHALL execute tests verifying correct resolution for all five shifts and all C5 boundary cases.
- THE SYSTEM SHALL include tests for C5 resolution in February (28/29 days) and at December/January year boundaries.

---

### Requirement 61: WorkDay Tests

**Priority:** P0

Tests must cover create, edit, and delete WorkDay operations.

#### Acceptance Criteria

- WHEN the test suite runs, THE SYSTEM SHALL execute tests verifying WorkDay creation persists correct data, editing updates correctly, and deletion removes all associated data including reminders.

---

### Requirement 62: Task Tests

**Priority:** P0

Tests must verify: add MW, remove MW, multiple tasks, and that tasks do not change shift time.

#### Acceptance Criteria

- WHEN the test suite runs, THE SYSTEM SHALL execute a test verifying that adding MW to a WorkDay does not alter resolved start, end, break start, or break end.
- WHEN the test suite runs, THE SYSTEM SHALL execute a test verifying that removing MW from a WorkDay does not alter resolved start, end, break start, or break end.

---

### Requirement 63: Note Tests

**Priority:** P0

Tests must verify add note, edit note, and delete note operations.

#### Acceptance Criteria

- WHEN the test suite runs, THE SYSTEM SHALL execute tests verifying note persistence, modification, and deletion without affecting other WorkDay fields.

---

### Requirement 64: Reminder Tests

**Priority:** P0

Tests must verify: create reminder, change shift updates reminder, cancel old reminder, create new reminder, delete WorkDay cancels reminder.

#### Acceptance Criteria

- WHEN the test suite runs, THE SYSTEM SHALL execute tests verifying the complete reminder lifecycle: creation, update on shift change, and cancellation on WorkDay deletion.

---

### Requirement 65: Notification Permission Handling

**Priority:** P1

The application must handle notification permission states gracefully.

#### Acceptance Criteria

- WHEN the user has not yet granted notification permission and enables a reminder, THE SYSTEM SHALL request notification authorization.
- WHEN notification permission is denied, THE SYSTEM SHALL display a message explaining that reminders require notification permission and provide a route to system Settings.
- THE SYSTEM SHALL NOT repeatedly prompt for permission if already denied.
