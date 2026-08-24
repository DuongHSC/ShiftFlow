// ShiftFlow — Persistence Layer
// SwiftData/ScheduleRuleModel.swift
//
// TASK-PERSISTENCE-001: SwiftData model for ScheduleRule.
//
// Persistence-layer @Model only. No resolution logic. Maps to/from the pure
// domain `ScheduleRule` value type.
//
// Note: domain `ScheduleRule` has no createdAt/modifiedAt; this model adds
// timestamps for persistence/sync bookkeeping without affecting the domain.
//
// CloudKit compatibility: no @Attribute(.unique); defaults on all stored props.

import Foundation
import SwiftData
import ShiftFlowDomain

/// SwiftData persistence model for a schedule rule (conditional override).
@Model
public final class ScheduleRuleModel {

    public var id: UUID = UUID()
    public var shiftID: UUID = UUID()

    public var startDayOfMonth: Int = 1
    public var endDayOfMonth: Int = 1

    public var overrideStartHour: Int = 0
    public var overrideStartMinute: Int = 0
    public var overrideEndHour: Int = 0
    public var overrideEndMinute: Int = 0
    public var overrideBreakStartHour: Int = 0
    public var overrideBreakStartMinute: Int = 0
    public var overrideBreakEndHour: Int = 0
    public var overrideBreakEndMinute: Int = 0

    public var priority: Int = 0
    public var isActive: Bool = true
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        shiftID: UUID,
        startDayOfMonth: Int, endDayOfMonth: Int,
        overrideStartHour: Int, overrideStartMinute: Int,
        overrideEndHour: Int, overrideEndMinute: Int,
        overrideBreakStartHour: Int, overrideBreakStartMinute: Int,
        overrideBreakEndHour: Int, overrideBreakEndMinute: Int,
        priority: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.shiftID = shiftID
        self.startDayOfMonth = startDayOfMonth
        self.endDayOfMonth = endDayOfMonth
        self.overrideStartHour = overrideStartHour
        self.overrideStartMinute = overrideStartMinute
        self.overrideEndHour = overrideEndHour
        self.overrideEndMinute = overrideEndMinute
        self.overrideBreakStartHour = overrideBreakStartHour
        self.overrideBreakStartMinute = overrideBreakStartMinute
        self.overrideBreakEndHour = overrideBreakEndHour
        self.overrideBreakEndMinute = overrideBreakEndMinute
        self.priority = priority
        self.isActive = isActive
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension ScheduleRuleModel {

    convenience init(from domain: ScheduleRule) {
        self.init(
            id: domain.id,
            shiftID: domain.shiftID,
            startDayOfMonth: domain.startDayOfMonth,
            endDayOfMonth: domain.endDayOfMonth,
            overrideStartHour: domain.startHour, overrideStartMinute: domain.startMinute,
            overrideEndHour: domain.endHour, overrideEndMinute: domain.endMinute,
            overrideBreakStartHour: domain.breakStartHour, overrideBreakStartMinute: domain.breakStartMinute,
            overrideBreakEndHour: domain.breakEndHour, overrideBreakEndMinute: domain.breakEndMinute,
            priority: domain.priority,
            isActive: domain.isActive
        )
    }

    func toDomain() -> ScheduleRule {
        ScheduleRule(
            id: id,
            shiftID: shiftID,
            startDayOfMonth: startDayOfMonth,
            endDayOfMonth: endDayOfMonth,
            startHour: overrideStartHour, startMinute: overrideStartMinute,
            endHour: overrideEndHour, endMinute: overrideEndMinute,
            breakStartHour: overrideBreakStartHour, breakStartMinute: overrideBreakStartMinute,
            breakEndHour: overrideBreakEndHour, breakEndMinute: overrideBreakEndMinute,
            priority: priority,
            isActive: isActive
        )
    }

    /// Updates fields from a domain value. id/shiftID preserved.
    func update(from domain: ScheduleRule) {
        self.startDayOfMonth = domain.startDayOfMonth
        self.endDayOfMonth = domain.endDayOfMonth
        self.overrideStartHour = domain.startHour
        self.overrideStartMinute = domain.startMinute
        self.overrideEndHour = domain.endHour
        self.overrideEndMinute = domain.endMinute
        self.overrideBreakStartHour = domain.breakStartHour
        self.overrideBreakStartMinute = domain.breakStartMinute
        self.overrideBreakEndHour = domain.breakEndHour
        self.overrideBreakEndMinute = domain.breakEndMinute
        self.priority = domain.priority
        self.isActive = domain.isActive
        self.modifiedAt = Date()
    }
}
