# ShiftFlow — Product Specification

**Product:** ShiftFlow  
**Version:** v0.1.1  
**Status:** Approved Baseline  
**Platform:** iOS  
**Product Type:** Personal shift-management application

---

# 1. Product Vision

ShiftFlow is a simple personal iOS application for managing irregular work shifts.

The primary goal is:

> Let the user quickly see what shift they work on a specific day, automatically calculate the correct working hours, attach additional tasks such as MW, add notes, and receive reminders.

The product should be significantly simpler than a general-purpose calendar application such as Google Calendar.

The core concept is:

```text
Date
  ↓
Shift
  ↓
Automatically resolved working time
  ↓
Optional Task
  ↓
Optional Note
  ↓
Optional Reminder
```

---

# 2. Target User

The primary user works irregular shifts and needs a fast way to manage a monthly work schedule on an iPhone.

The user should not need to manually calculate working hours after selecting a shift.

---

# 3. Core Shift Definitions

ShiftFlow initially supports five shifts.

## C1

```text
Start: 07:00
End: 16:30
Break: 11:00 → 12:00
```

## C2

```text
Start: 07:30
End: 17:00
Break: 11:30 → 12:30
```

## C3

```text
Start: 08:00
End: 17:30
Break: 12:00 → 13:00
```

## C4

```text
Start: 08:30
End: 18:00
Break: 12:30 → 13:30
```

## C5

Normal schedule:

```text
Start: 11:30
End: 21:00
Break: 16:30 → 17:30
```

Special schedule:

```text
Calendar day 10 through calendar day 20
Start: 12:00
End: 21:30
Break: 16:30 → 17:30
```

Boundary behavior:

```text
Day 9  → C5 normal
Day 10 → C5 special
Day 20 → C5 special
Day 21 → C5 normal
```

The C5 rule applies independently in every month.

---

# 4. Automatic Shift Resolution

The user selects a shift for a date.

The application automatically determines the working schedule.

Example:

```text
User selects:

15 August
C5

        ↓

ShiftResolver

        ↓

12:00 → 21:30
Break 16:30 → 17:30
```

The user should not manually enter standard shift hours.

The same resolution result must be used by:

- Calendar
- Today
- Week
- 3 Days
- Reminder
- Widget

---

# 5. Historical Schedule Safety

Historical work-day information must not unexpectedly change when the user modifies shift configuration for future use.

The approved approach is:

> Snapshot the resolved working schedule into the WorkDay when the schedule is saved.

Conceptually:

```text
Shift Configuration
        ↓
ShiftResolver
        ↓
ResolvedShift
        ↓
WorkDay stores resolved snapshot
```

A WorkDay should therefore retain the resolved:

```text
Start
End
Break Start
Break End
```

This protects historical schedule information.

Future configuration changes apply to future WorkDays and do not silently rewrite historical WorkDays.

---

# 6. Tasks

A task is additional work attached to a WorkDay.

A task is NOT a shift.

Initial task:

```text
MW
```

MW may be attached to a work day.

Adding or removing MW must never modify:

```text
Start
End
Break
```

Future tasks may include other work activities.

The task system should therefore be extensible.

---

# 7. Notes

A WorkDay may contain an optional plain-text note.

Examples:

```text
Họp team lúc 14:00
```

```text
Nhớ kiểm tra ticket
```

Notes are informational and must not affect shift calculations.

---

# 8. Calendar Views

The application should provide:

```text
This Month
This Week
3 Days
Today
```

## This Month

Default view.

Primary purpose:

> Quickly understand the entire monthly work schedule.

Display:

```text
Date
Shift code
Task indicator
Note indicator
```

Do not show full working hours in every calendar cell.

## This Week

Display seven days with more schedule detail.

## 3 Days

Display:

```text
Today
Tomorrow
Following day
```

## Today

Display:

```text
Today's shift
Working time
Break
Tasks
Note
Next scheduled shift
```

---

# 9. Day Detail

Selecting a date opens a Day Detail sheet.

The sheet allows the user to:

```text
Select Shift
View resolved working time
Add/remove Task
Edit Note
Configure Reminder
Save
Delete
```

The normal user workflow changes the Shift, not the calculated working hours.

---

# 10. Settings

Settings must allow the user to change shift configuration.

The user should be able to configure:

```text
C1
C2
C3
C4
C5
```

including:

```text
Start
End
Break
```

The user must also be able to configure special schedule rules.

Example:

```text
C5
Day 10 → Day 20
12:00 → 21:30
```

The configuration system must be data-driven.

Shift times must not be hard-coded inside SwiftUI views.

---

# 11. OFF / No Shift

ShiftFlow does not require a persistent OFF ShiftDefinition for MVP.

The domain meaning is:

```text
WorkDay exists
    → scheduled shift

No WorkDay exists
    → no shift scheduled
```

The UI may display:

```text
OFF
```

as a presentation state when appropriate.

OFF is not one of C1–C5.

This avoids creating unnecessary persistent schedule data.

---

# 12. Reminders

The user may enable a reminder for a WorkDay.

Supported offsets:

```text
30 minutes before
1 hour before
2 hours before
24 hours before
```

"1 day before" means exactly:

```text
24 hours before the resolved shift start
```

Example:

```text
Shift start:
07:00 on August 20

Reminder:
07:00 on August 19
```

Reminder time must be calculated from the WorkDay's resolved schedule.

When a WorkDay changes:

```text
Cancel old reminder
        ↓
Resolve updated schedule
        ↓
Create updated reminder
```

When a WorkDay is deleted:

```text
Cancel associated reminder
```

---

# 13. Notification Scheduling Strategy

iOS local notifications have system limits.

ShiftFlow must not attempt to schedule an unlimited number of future notifications.

The initial strategy is a rolling notification window:

```text
Next 7–14 days
```

The application should refresh the notification window when appropriate.

The exact scheduling mechanism must respect iOS `UNUserNotificationCenter` limitations.

Notification registrations are device-local.

They are not shared CloudKit records.

---

# 14. Home Screen Widget

ShiftFlow should provide an iOS Home Screen Widget.

Target sizes:

```text
Small
Medium
Large
```

## Small

Primary information:

```text
Today's shift
Working time
Task indicator
```

## Medium

Primary information:

```text
Today
Next shift
```

## Large

Primary information:

```text
Short upcoming schedule
```

Widget information must come from the same underlying schedule/domain logic as the main application.

The Widget must not implement its own C5 rules.

Widget refresh is system-controlled and should be requested when relevant data changes.

---

# 15. Widget Shared Domain

Because the Widget is a separate target, the architecture must make the schedule domain reusable.

At minimum, the following domain logic must be shareable between the application and Widget:

```text
ShiftDefinition
ScheduleRule
ResolvedShift
ShiftResolver
```

The implementation may use a shared Swift Package, framework, or another appropriate target-sharing mechanism.

The final implementation choice must be documented in architecture.md.

---

# 16. Offline First

ShiftFlow must remain useful without Internet access.

Offline operations include:

```text
View calendar
Create WorkDay
Edit WorkDay
Delete WorkDay
Add/remove tasks
Edit notes
View shift configuration
```

Cloud synchronization is secondary to local usability.

---

# 17. iCloud Sync

The application should synchronize personal schedule data across the user's Apple devices using CloudKit.

Syncable data includes:

```text
WorkDay
ShiftDefinition
ScheduleRule
TaskDefinition
AppSettings
```

Notifications remain device-local.

The application must continue functioning if CloudKit is temporarily unavailable.

CloudKit implementation is a later phase and must not block the core offline application.

---

# 18. Sync Conflict Policy

The initial recommended policy is:

```text
Last modification wins
```

using modification timestamps.

This policy must be deterministic and documented before CloudKit implementation is considered complete.

---

# 19. User Experience Principles

ShiftFlow should feel:

```text
Simple
Fast
Clean
Native to iOS
Low friction
Visual
Personal
```

The user should understand today's schedule within a few seconds.

Avoid excessive configuration and unnecessary screens.

---

# 20. Do Not Become Google Calendar

ShiftFlow is not intended to become a general-purpose calendar.

Do not introduce these features unless explicitly approved:

```text
Meeting attendees
Calendar accounts
Event invitations
Complex recurring events
Hourly event grids
Multiple calendar providers
Complex event categories
```

The core product remains:

```text
Date → Shift → Task → Note
```

---

# 21. Product Scope

## MVP / P0

```text
Five shifts
Automatic shift resolution
C5 day 10–20 rule
Historical WorkDay snapshot
WorkDay CRUD
MW task
Notes
Month view
Day detail
Settings
Offline local storage
```

## P1

```text
Week view
3 Days view
Today view
Reminders
Task configuration
Historical configuration UI
Accessibility improvements
```

## P2

```text
Home Screen Widget
CloudKit sync
Multi-device synchronization
Advanced UI polish
```

---

# 22. Success Criteria

ShiftFlow is successful when the user can:

1. Open the app and immediately understand today's shift.
2. Add a shift to a date with minimal interaction.
3. Have working hours calculated automatically.
4. Correctly handle C5 day 10–20.
5. Add MW without changing shift time.
6. Add a note.
7. Configure shift times from Settings.
8. Receive a reminder before a shift.
9. Continue using the app offline.
10. Eventually synchronize the schedule across Apple devices.
11. See consistent schedule information in the app and Widget.

---

# 23. Product Change Control

Any change to the product scope must:

```text
Be documented
↓
Receive a version
↓
Update relevant requirements/design/tasks
↓
Update CHANGELOG.md
```

Kiro must not silently add product features.

---

# 24. Current Baseline

```text
Version: v0.1.1
Status: Approved after specification review
Product: ShiftFlow
Platform: iOS
```

This document replaces the incorrect previous product.md content.

End of Product Specification.
