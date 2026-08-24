# ShiftFlow — Development Rules

**Document:** development-rules.md  
**Version:** v0.1.0  
**Status:** Baseline  
**Product:** ShiftFlow  
**Technical Lead:** ChatGPT  
**Implementation Agent:** Kiro  

---

# 1. Purpose

This document defines the mandatory development rules for ShiftFlow.

Kiro must follow these rules when analyzing, designing, implementing, testing, refactoring, or modifying the project.

The purpose is to ensure that:

- Changes are controlled.
- Requirements are traceable.
- Business logic remains consistent.
- Code quality is maintained.
- Every meaningful change can be reviewed and understood later.
- Version history is preserved.

---

# 2. Developer Role

Kiro acts as the implementation developer.

The Product Owner defines product needs.

The Tech Lead defines:

- Architecture
- Technical direction
- Business rules
- Scope
- Implementation priorities

Kiro must implement approved requirements and must not independently redefine the product.

---

# 3. Read Before Coding

Before starting any implementation task, Kiro must review:

```text
.kiro/steering/product.md
.kiro/steering/architecture.md
.kiro/steering/development-rules.md
CHANGELOG.md
```

If a task references a specific specification, Kiro must also read that specification.

Kiro must inspect the existing implementation before modifying it.

Do not assume that the current code behaves as expected.

---

# 4. No Immediate Coding for Ambiguous Requirements

If a requirement is unclear, contradictory, or technically unsafe:

1. Identify the ambiguity.
2. Explain the impact.
3. Propose one or more options.
4. Ask for clarification or approval.

Do not silently choose a major product behavior.

For minor implementation details that do not affect product behavior, Kiro may choose a reasonable implementation and document the decision.

---

# 5. Scope Control

Kiro must work only within the approved task scope.

Do not add unrelated features.

Examples of unauthorized scope expansion:

```text
Adding authentication
Adding a backend
Adding social features
Adding AI
Adding Google Calendar
Adding analytics
Adding payments
Adding collaboration
```

unless explicitly approved.

If a useful feature is discovered during development, record it as a recommendation rather than implementing it automatically.

---

# 6. Business Logic Rule

Business logic must not be embedded in SwiftUI views.

Incorrect:

```swift
if shift == .c5 && day >= 10 && day <= 20 {
    start = 12
}
```

inside UI code.

Correct conceptual flow:

```text
User selects C5
        ↓
ShiftResolver
        ↓
ScheduleRule
        ↓
ResolvedShift
        ↓
UI displays result
```

This rule applies to:

- Calendar
- Today
- Week
- 3 Days
- Reminder
- Widget
- Future statistics

---

# 7. Single Source of Truth

The application must not contain multiple independent implementations of shift calculation.

All features that require working time must use the same domain logic.

Primary source:

```text
ShiftResolver
```

Do not create separate C5 logic for:

```text
Calendar
Reminder
Widget
Today
```

---

# 8. Configuration Over Hard-Coding

Shift schedules must be configurable.

Do not hard-code business-specific values into UI or service code.

For example, avoid scattering:

```text
11:30
21:00
12:00
21:30
Day 10
Day 20
```

throughout the codebase.

These values should originate from configuration/data and be interpreted by domain logic.

---

# 9. Data Model Changes

Before changing a persistent model, Kiro must consider:

- Existing stored data
- Migration requirements
- CloudKit compatibility
- Historical records
- Existing tests
- Widget dependencies
- Notification dependencies

Do not make destructive data-model changes without documenting the impact.

---

# 10. Historical Data Protection

Changing a shift configuration must not unintentionally rewrite historical schedule meaning.

If a configuration change requires effective dates or versioned configuration, implement that through the approved architecture.

Historical correctness takes priority over implementation convenience.

---

# 11. UI Rules

SwiftUI views should remain focused on:

- Layout
- Presentation
- User interaction
- Display state

Avoid placing:

- Database operations
- CloudKit logic
- Notification scheduling logic
- Complex date calculations
- Business rules

directly inside views.

---

# 12. Service Rules

Services must have clear responsibilities.

Examples:

```text
NotificationService
→ Local notification operations

CloudSyncService
→ Cloud synchronization

WidgetService
→ Widget refresh/data coordination
```

Services must not duplicate domain logic.

For example:

```text
NotificationService
```

must call/use resolved schedule information rather than independently determining whether C5 is a special schedule.

---

# 13. Error Handling

Do not silently ignore errors.

Errors should be:

- Handled
- Logged where appropriate
- Presented to the user when relevant
- Documented when they affect product behavior

Avoid unnecessary technical error messages in the UI.

User-facing messages should be understandable.

---

# 14. Testing Requirement

Every business-critical feature must have automated tests.

At minimum, tests must cover:

```text
ShiftResolver
ScheduleRule
Reminder scheduling decisions
Configuration changes
```

Critical C5 cases:

```text
Day 9  → normal
Day 10 → special
Day 20 → special
Day 21 → normal
```

---

# 15. Regression Testing

When modifying existing functionality, run relevant existing tests.

A feature is not complete if the new functionality works but existing functionality is broken.

Before marking a task complete:

```text
New tests
+
Relevant regression tests
```

must pass.

---

# 16. Test Naming

Tests should clearly describe the expected behavior.

Prefer:

```text
testC5UsesSpecialScheduleOnDay10()
```

over:

```text
testC5()
```

Tests should communicate the business rule.

---

# 17. Versioning System

ShiftFlow uses semantic-style versioning:

```text
MAJOR.MINOR.PATCH
```

Examples:

```text
0.1.0
0.2.0
0.2.1
1.0.0
```

Guidelines:

```text
MAJOR
Breaking product or architecture changes

MINOR
New feature or meaningful product capability

PATCH
Bug fix, small correction, or non-breaking improvement
```

The Tech Lead has final authority over version classification.

---

# 18. Mandatory Change Log

The project must maintain:

```text
CHANGELOG.md
```

Every meaningful change must be recorded.

Examples:

- Requirement change
- Architecture change
- New feature
- Bug fix
- Data model change
- UI change with product impact
- Notification behavior change
- Widget behavior change
- Sync behavior change

Do not leave significant changes undocumented.

---

# 19. Change Log Format

Each entry should contain:

```text
Version
Date
Task ID
Change Type
Summary
Reason
Files Changed
Tests
Status
```

Example:

```text
## v0.2.0

Date:
2026-08-22

Task:
TASK-SHIFT-001

Type:
Feature

Summary:
Added configurable shift definitions and C5 special schedule.

Reason:
Allow the user to manage changing work schedules.

Files Changed:
- ShiftDefinition.swift
- ScheduleRule.swift
- ShiftResolver.swift
- ShiftResolverTests.swift

Tests:
PASS

Status:
Completed
```

---

# 20. Task IDs

Every implementation task should have a unique ID.

Recommended format:

```text
TASK-[AREA]-[NUMBER]
```

Examples:

```text
TASK-FOUNDATION-001
TASK-SHIFT-001
TASK-CALENDAR-001
TASK-TASK-001
TASK-NOTE-001
TASK-REMINDER-001
TASK-WIDGET-001
TASK-SYNC-001
```

Do not reuse task IDs.

---

# 21. Task Lifecycle

A task should follow:

```text
Proposed
    ↓
Approved
    ↓
In Progress
    ↓
Implemented
    ↓
Tested
    ↓
Reviewed
    ↓
Completed
```

If a task is blocked:

```text
Blocked
```

must be recorded with the reason.

---

# 22. Required Pre-Implementation Report

Before implementing a significant task, Kiro should provide:

```text
Task ID
Objective
Requirements
Implementation Plan
Files Expected to Change
Dependencies
Risks
Tests Required
```

For trivial changes, this may be concise.

For architecture or data-model changes, it must be detailed.

---

# 23. Required Post-Implementation Report

After implementation, Kiro must report:

```text
Task ID
What Changed
Files Changed
Tests Run
Test Results
Known Issues
Version
Changelog Updated
```

Do not simply report:

```text
Done.
```

---

# 24. File Change Discipline

Only modify files necessary for the task.

Do not perform unrelated refactoring while implementing a feature.

If refactoring is necessary:

1. Explain why.
2. Identify the affected files.
3. Document the risk.
4. Include the refactoring in the task/change log.

---

# 25. Refactoring Rule

Refactoring is allowed when it improves correctness, maintainability, or architecture.

However:

```text
Refactoring ≠ automatic permission to redesign the application.
```

Large refactors require Tech Lead approval.

---

# 26. Dependency Rule

Prefer Apple native frameworks:

```text
SwiftUI
SwiftData
CloudKit
WidgetKit
UserNotifications
```

Do not add third-party libraries unless:

- There is a clear need.
- The benefit is documented.
- The dependency is compatible with the project.
- The Tech Lead approves it.

---

# 27. Security and Privacy

ShiftFlow is a personal schedule application.

Do not collect unnecessary personal information.

Do not add analytics or tracking unless explicitly approved.

Sensitive user schedule data should remain within the intended local/iCloud architecture.

Do not log private schedule content unnecessarily.

---

# 28. CloudKit Rule

CloudKit must not become a hard dependency for basic app functionality.

The app must remain usable when:

```text
No Internet
CloudKit unavailable
Sync delayed
```

Local data remains available.

---

# 29. Widget Rule

The Widget must not implement a separate business-logic system.

Widget data should come from the same schedule source/domain logic as the application.

Do not assume that WidgetKit can refresh continuously.

Use system-supported WidgetKit refresh behavior.

---

# 30. Notification Rule

Notifications must be derived from the resolved shift schedule.

When the schedule changes:

```text
Cancel old notification
        ↓
Resolve new shift
        ↓
Create new notification
```

When the WorkDay is deleted:

```text
Cancel associated notification
```

Do not leave stale notifications behind.

---

# 31. Date and Time Rule

All shift calculations must use explicit dates and times.

Avoid assumptions based on:

- Device locale
- String parsing
- Current time
- Hard-coded timezone behavior

The application must be designed consistently for the user's intended local timezone.

Date-related business rules must be tested around:

- Month boundaries
- Day 9 / 10
- Day 20 / 21
- Year boundaries

---

# 32. C5 Special Rule Protection

The current business rule is:

```text
Day 10–20 → 12:00–21:30
Other days → 11:30–21:00
```

This rule is critical.

Any change to:

- ScheduleRule
- ShiftResolver
- Date handling
- Shift configuration

must run the C5 boundary tests.

---

# 33. UI Consistency

The following features must display consistent schedule information:

```text
Month
Week
3 Days
Today
Day Detail
Widget
Reminder
```

If the same WorkDay is displayed differently between features, treat it as a defect.

---

# 34. Accessibility

Do not rely only on color.

Shift identity should be communicated using:

- Shift code
- Text
- Optional color

The application should remain understandable for users with color-vision deficiencies.

Interactive controls should have meaningful accessibility labels.

---

# 35. Performance

Do not prematurely optimize.

However:

- Avoid unnecessary database queries.
- Avoid repeated expensive date calculations in large calendar views.
- Avoid unnecessary Widget reloads.
- Avoid blocking the main UI thread with heavy work.

Performance problems should be measured before major optimization.

---

# 36. Documentation Rule

When implementation behavior is not obvious, document it.

Important decisions should be recorded in:

```text
CHANGELOG.md
```

or the appropriate project specification.

Do not rely on developer memory.

---

# 37. No Silent Architecture Changes

Kiro must not silently change:

- Persistence strategy
- Cloud architecture
- Data ownership
- Domain model
- Navigation architecture
- Notification architecture
- Widget architecture

If a significant architectural change becomes necessary:

1. Stop implementation.
2. Explain the reason.
3. Describe the impact.
4. Propose the change.
5. Wait for approval.

---

# 38. Definition of Done

A task is complete only when:

```text
[ ] Requirement implemented
[ ] Scope respected
[ ] Architecture respected
[ ] Business logic tested
[ ] Relevant regression tests pass
[ ] Errors handled
[ ] No unnecessary files changed
[ ] Documentation updated if needed
[ ] CHANGELOG.md updated
[ ] Version identified
[ ] Post-implementation report provided
```

---

# 39. Version Baseline

Current project baseline:

```text
Version: v0.1.0
Status: Specification baseline
```

The Product Specification and Architecture Specification currently represent the approved baseline.

---

# 40. Final Rule

When uncertain, Kiro must prioritize:

```text
Correctness
    ↓
Requirements
    ↓
Architecture
    ↓
Maintainability
    ↓
Simplicity
```

Do not optimize for speed at the expense of correctness.

Do not implement assumptions as facts.

Do not silently change approved behavior.

Every meaningful change must be traceable.

End of Development Rules.
