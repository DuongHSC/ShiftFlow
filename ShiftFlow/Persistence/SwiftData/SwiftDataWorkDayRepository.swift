// ShiftFlow — Persistence Layer
// SwiftData/SwiftDataWorkDayRepository.swift
//
// TASK-INTEGRATION-001: SwiftData-backed WorkDayRepository.
//
// Concrete implementation of the domain's WorkDayRepository protocol using
// SwiftData. Maps between WorkDayModel (@Model) and the domain WorkDay value.
//
// Enforces "one WorkDay per date" at this layer (CloudKit has no unique
// constraint). Uses ModelContext for all persistence operations.

import Foundation
import SwiftData
import ShiftFlowDomain

/// SwiftData implementation of `WorkDayRepository`.
public final class SwiftDataWorkDayRepository: WorkDayRepository {

    private let modelContext: ModelContext
    private let calendar: Calendar

    public init(modelContext: ModelContext, calendar: Calendar = .current) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    // MARK: - Create

    public func create(_ workDay: WorkDay) throws {
        // Enforce one WorkDay per date (CloudKit-safe uniqueness).
        if try fetchModelByDate(workDay.date) != nil {
            throw WorkDayRepositoryError.duplicateDate(calendar.startOfDay(for: workDay.date))
        }

        let model = WorkDayModel(from: workDay)
        modelContext.insert(model)
        try save()
    }

    // MARK: - Read

    public func fetchByID(_ id: UUID) throws -> WorkDay? {
        try fetchModelByID(id)?.toDomain()
    }

    public func fetchByDate(_ date: Date) throws -> WorkDay? {
        try fetchModelByDate(date)?.toDomain()
    }

    public func fetchByDateRange(from startDate: Date, to endDate: Date) throws -> [WorkDay] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        let descriptor = FetchDescriptor<WorkDayModel>(
            predicate: #Predicate { model in
                model.date >= start && model.date <= end
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    // MARK: - Update

    public func update(_ workDay: WorkDay) throws {
        guard let model = try fetchModelByID(workDay.id) else {
            throw WorkDayRepositoryError.notFound(workDay.id)
        }
        model.update(from: workDay)
        try save()
    }

    // MARK: - Delete

    public func delete(_ id: UUID) throws {
        guard let model = try fetchModelByID(id) else {
            throw WorkDayRepositoryError.notFound(id)
        }
        modelContext.delete(model)
        try save()
    }

    // MARK: - All IDs

    public func allIDs() throws -> Set<UUID> {
        let descriptor = FetchDescriptor<WorkDayModel>()
        let models = try modelContext.fetch(descriptor)
        return Set(models.map { $0.id })
    }

    // MARK: - Private Helpers

    private func fetchModelByID(_ id: UUID) throws -> WorkDayModel? {
        let descriptor = FetchDescriptor<WorkDayModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func fetchModelByDate(_ date: Date) throws -> WorkDayModel? {
        let start = calendar.startOfDay(for: date)
        // Compare against the normalized start-of-day.
        let descriptor = FetchDescriptor<WorkDayModel>(
            predicate: #Predicate { $0.date == start }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw WorkDayRepositoryError.persistenceFailed(error.localizedDescription)
        }
    }
}
