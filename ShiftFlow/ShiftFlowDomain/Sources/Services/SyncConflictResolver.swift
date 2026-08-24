// ShiftFlow — Domain Layer
// Services/SyncConflictResolver.swift
//
// TASK-CLOUDKIT-001: Deterministic sync conflict resolution (pure logic).
//
// This resolver decides which WorkDay wins when the same record is edited
// on two devices. It is pure and testable — no CloudKit dependency.
//
// CRITICAL RULES:
// - Never recalculate a WorkDay's resolved snapshot from global configuration.
// - Preserve a complete, valid WorkDay record.
// - Deterministic: "last modification wins" using modifiedAt.
// - One WorkDay per calendar date — resolve date-collisions deterministically.

import Foundation

/// Resolves CloudKit sync conflicts for WorkDay records deterministically.
///
/// The policy is "last modification wins" based on `modifiedAt`, with a
/// stable tiebreaker (larger UUID string) so the result is fully deterministic.
///
/// The winning record's resolved snapshot is preserved as-is — it is NEVER
/// recalculated from the current ShiftDefinition.
public enum SyncConflictResolver {

    /// Resolves a conflict between two versions of the SAME WorkDay (same id).
    ///
    /// - Parameters:
    ///   - local: The local version.
    ///   - remote: The remote (synced) version.
    /// - Returns: The winning WorkDay (snapshot preserved, not recalculated).
    public static func resolveSameRecord(local: WorkDay, remote: WorkDay) -> WorkDay {
        // Last modification wins.
        if local.modifiedAt > remote.modifiedAt {
            return local
        }
        if remote.modifiedAt > local.modifiedAt {
            return remote
        }
        // Tie on modifiedAt — deterministic tiebreaker by id string.
        return local.id.uuidString >= remote.id.uuidString ? local : remote
    }

    /// Resolves a date-collision where two DIFFERENT WorkDay records
    /// (different ids) claim the same calendar date after sync.
    ///
    /// Enforces "one WorkDay per date" by selecting exactly one winner.
    ///
    /// - Parameters:
    ///   - candidates: WorkDays that all share the same calendar date.
    ///   - calendar: Calendar for date comparison.
    /// - Returns: The single winning WorkDay to keep, and the losers to remove.
    public static func resolveDateCollision(
        candidates: [WorkDay]
    ) -> (winner: WorkDay?, losers: [WorkDay]) {
        guard !candidates.isEmpty else { return (nil, []) }
        guard candidates.count > 1 else { return (candidates[0], []) }

        // Winner = most recently modified; tiebreak by id string.
        let sorted = candidates.sorted { a, b in
            if a.modifiedAt != b.modifiedAt {
                return a.modifiedAt > b.modifiedAt
            }
            return a.id.uuidString > b.id.uuidString
        }

        let winner = sorted[0]
        let losers = Array(sorted.dropFirst())
        return (winner, losers)
    }

    /// Detects date collisions in a set of WorkDays (post-sync integrity check).
    ///
    /// - Parameters:
    ///   - workDays: All WorkDays to check.
    ///   - calendar: Calendar for grouping by day.
    /// - Returns: Groups of WorkDays that share the same calendar date (size > 1).
    public static func detectDateCollisions(
        workDays: [WorkDay],
        calendar: Calendar = .current
    ) -> [[WorkDay]] {
        var byDay: [Date: [WorkDay]] = [:]
        for wd in workDays {
            let key = calendar.startOfDay(for: wd.date)
            byDay[key, default: []].append(wd)
        }
        return byDay.values.filter { $0.count > 1 }.map { $0 }
    }
}
