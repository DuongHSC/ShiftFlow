// ShiftFlow — Domain Layer
// Services/TaskSeedProvider.swift
//
// TASK-TASK-001: Default task seeding.
//
// Provides the default MW task with a stable UUID for idempotent seeding.

import Foundation

/// Provides default task definitions for first-launch seeding.
public enum TaskSeedProvider {

    /// Stable ID for the default MW task (idempotent seeding).
    public static let mwID = UUID(uuidString: "00000010-0010-0010-0010-000000000010")!

    /// The default MW task.
    public static func makeMW(createdAt: Date = Date()) -> TaskDefinition {
        TaskDefinition(
            id: mwID,
            code: "MW",
            name: "MW",
            isActive: true,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    /// All default task definitions.
    public static func allDefaultTasks(createdAt: Date = Date()) -> [TaskDefinition] {
        [makeMW(createdAt: createdAt)]
    }

    /// Returns the tasks that should be seeded, excluding IDs already present.
    /// Ensures idempotent seeding (no duplicates).
    public static func tasksToSeed(existingIDs: Set<UUID>, createdAt: Date = Date()) -> [TaskDefinition] {
        allDefaultTasks(createdAt: createdAt).filter { !existingIDs.contains($0.id) }
    }
}
