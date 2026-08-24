// ShiftFlow — Domain Layer
// Services/WorkDayRepository.swift
//
// TASK-WORKDAY-001: WorkDay repository protocol.
//
// Defines the persistence interface for WorkDay operations.
// The domain layer depends on this protocol (not on SwiftData directly).
// Concrete implementations live in the Persistence layer.

import Foundation

/// Errors that can occur during WorkDay repository operations.
public enum WorkDayRepositoryError: Error, Equatable {
    /// A WorkDay already exists for the specified date.
    case duplicateDate(Date)
    /// The specified WorkDay was not found.
    case notFound(UUID)
    /// A persistence operation failed.
    case persistenceFailed(String)
}

/// Protocol defining WorkDay persistence operations.
///
/// Implementations may use SwiftData, in-memory storage (for testing),
/// or any other persistence mechanism.
///
/// The repository enforces the "one WorkDay per date" constraint.
public protocol WorkDayRepository {

    /// Saves a new WorkDay. Fails if a WorkDay already exists for that date.
    func create(_ workDay: WorkDay) throws

    /// Retrieves a WorkDay by its ID.
    func fetchByID(_ id: UUID) throws -> WorkDay?

    /// Retrieves a WorkDay for a specific calendar date.
    func fetchByDate(_ date: Date) throws -> WorkDay?

    /// Retrieves all WorkDays within a date range (inclusive).
    func fetchByDateRange(from startDate: Date, to endDate: Date) throws -> [WorkDay]

    /// Updates an existing WorkDay. Fails if not found.
    func update(_ workDay: WorkDay) throws

    /// Deletes a WorkDay by its ID. Fails if not found.
    func delete(_ id: UUID) throws

    /// Returns all existing WorkDay IDs (useful for batch operations).
    func allIDs() throws -> Set<UUID>
}
