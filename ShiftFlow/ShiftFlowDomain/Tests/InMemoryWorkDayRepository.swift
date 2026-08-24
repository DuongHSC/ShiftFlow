// ShiftFlow — Domain Tests
// InMemoryWorkDayRepository.swift
//
// TASK-WORKDAY-001: In-memory implementation of WorkDayRepository for testing.
//
// This allows comprehensive testing of WorkDayService without SwiftData.

import Foundation
@testable import ShiftFlowDomain

/// In-memory WorkDay repository for unit testing.
final class InMemoryWorkDayRepository: WorkDayRepository {

    private var storage: [UUID: WorkDay] = [:]

    /// Calendar used for date normalization in comparisons.
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func create(_ workDay: WorkDay) throws {
        // Check for duplicate date.
        let normalizedDate = calendar.startOfDay(for: workDay.date)
        let existingForDate = storage.values.first {
            calendar.isDate($0.date, inSameDayAs: normalizedDate)
        }
        if existingForDate != nil {
            throw WorkDayRepositoryError.duplicateDate(normalizedDate)
        }

        storage[workDay.id] = workDay
    }

    func fetchByID(_ id: UUID) throws -> WorkDay? {
        storage[id]
    }

    func fetchByDate(_ date: Date) throws -> WorkDay? {
        let normalizedDate = calendar.startOfDay(for: date)
        return storage.values.first {
            calendar.isDate($0.date, inSameDayAs: normalizedDate)
        }
    }

    func fetchByDateRange(from startDate: Date, to endDate: Date) throws -> [WorkDay] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return storage.values.filter { workDay in
            let day = calendar.startOfDay(for: workDay.date)
            return day >= start && day <= end
        }.sorted { $0.date < $1.date }
    }

    func update(_ workDay: WorkDay) throws {
        guard storage[workDay.id] != nil else {
            throw WorkDayRepositoryError.notFound(workDay.id)
        }
        storage[workDay.id] = workDay
    }

    func delete(_ id: UUID) throws {
        guard storage[id] != nil else {
            throw WorkDayRepositoryError.notFound(id)
        }
        storage.removeValue(forKey: id)
    }

    func allIDs() throws -> Set<UUID> {
        Set(storage.keys)
    }

    // MARK: - Test Helpers

    /// Returns the current count of stored WorkDays.
    var count: Int { storage.count }

    /// Clears all stored data.
    func reset() { storage.removeAll() }
}
