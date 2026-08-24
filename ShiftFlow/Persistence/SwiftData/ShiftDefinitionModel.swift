// ShiftFlow — Persistence Layer
// SwiftData/ShiftDefinitionModel.swift
//
// TASK-PERSISTENCE-001: SwiftData model for ShiftDefinition.
//
// Persistence-layer @Model only. No business logic. Maps to/from the pure
// domain `ShiftDefinition` value type.
//
// CloudKit compatibility (same rules as WorkDayModel):
// - NO @Attribute(.unique)
// - all non-optional stored properties have defaults
// - stable UUID id

import Foundation
import SwiftData
import ShiftFlowDomain

/// SwiftData persistence model for a shift definition.
@Model
public final class ShiftDefinitionModel {

    public var id: UUID = UUID()
    /// Stable business identity (e.g., "C1"–"C5"). Not changed by editing.
    public var code: String = ""
    public var name: String = ""

    public var startHour: Int = 0
    public var startMinute: Int = 0
    public var endHour: Int = 0
    public var endMinute: Int = 0
    public var breakStartHour: Int = 0
    public var breakStartMinute: Int = 0
    public var breakEndHour: Int = 0
    public var breakEndMinute: Int = 0

    public var isActive: Bool = true
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        code: String,
        name: String,
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int,
        breakStartHour: Int, breakStartMinute: Int,
        breakEndHour: Int, breakEndMinute: Int,
        isActive: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.breakStartHour = breakStartHour
        self.breakStartMinute = breakStartMinute
        self.breakEndHour = breakEndHour
        self.breakEndMinute = breakEndMinute
        self.isActive = isActive
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension ShiftDefinitionModel {

    /// Creates a model from a domain value.
    convenience init(from domain: ShiftDefinition) {
        self.init(
            id: domain.id,
            code: domain.code,
            name: domain.name,
            startHour: domain.startHour, startMinute: domain.startMinute,
            endHour: domain.endHour, endMinute: domain.endMinute,
            breakStartHour: domain.breakStartHour, breakStartMinute: domain.breakStartMinute,
            breakEndHour: domain.breakEndHour, breakEndMinute: domain.breakEndMinute,
            isActive: domain.isActive,
            createdAt: domain.createdAt,
            modifiedAt: domain.modifiedAt
        )
    }

    /// Converts to a domain value.
    func toDomain() -> ShiftDefinition {
        ShiftDefinition(
            id: id,
            code: code,
            name: name,
            startHour: startHour, startMinute: startMinute,
            endHour: endHour, endMinute: endMinute,
            breakStartHour: breakStartHour, breakStartMinute: breakStartMinute,
            breakEndHour: breakEndHour, breakEndMinute: breakEndMinute,
            isActive: isActive,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    /// Updates fields from a domain value. Code/id are preserved (stable identity).
    func update(from domain: ShiftDefinition) {
        self.name = domain.name
        self.startHour = domain.startHour
        self.startMinute = domain.startMinute
        self.endHour = domain.endHour
        self.endMinute = domain.endMinute
        self.breakStartHour = domain.breakStartHour
        self.breakStartMinute = domain.breakStartMinute
        self.breakEndHour = domain.breakEndHour
        self.breakEndMinute = domain.breakEndMinute
        self.isActive = domain.isActive
        self.modifiedAt = domain.modifiedAt
    }
}
