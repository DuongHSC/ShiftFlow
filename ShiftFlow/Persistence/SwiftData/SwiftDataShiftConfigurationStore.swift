// ShiftFlow — Persistence Layer
// SwiftData/SwiftDataShiftConfigurationStore.swift
//
// TASK-PERSISTENCE-001: SwiftData-backed ShiftConfigurationStore.
//
// Conforms to the domain `ShiftConfigurationStore` protocol using SwiftData.
// Persists ShiftDefinitionModel + ScheduleRuleModel and maps to/from domain
// value types. No business/resolution logic here.

import Foundation
import SwiftData
import ShiftFlowDomain

/// SwiftData implementation of `ShiftConfigurationStore`.
public final class SwiftDataShiftConfigurationStore: ShiftConfigurationStore {

    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Read

    public func allDefinitions() -> [ShiftDefinition] {
        let descriptor = FetchDescriptor<ShiftDefinitionModel>(
            sortBy: [SortDescriptor(\.code, order: .forward)]
        )
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return models.map { $0.toDomain() }
    }

    public func allRules() -> [ScheduleRule] {
        let descriptor = FetchDescriptor<ScheduleRuleModel>()
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return models.map { $0.toDomain() }
    }

    // MARK: - Upsert

    public func upsertDefinition(_ def: ShiftDefinition) {
        if let existing = fetchDefinitionModel(id: def.id) {
            existing.update(from: def)
        } else {
            modelContext.insert(ShiftDefinitionModel(from: def))
        }
        try? modelContext.save()
    }

    public func upsertRule(_ rule: ScheduleRule) {
        if let existing = fetchRuleModel(id: rule.id) {
            existing.update(from: rule)
        } else {
            modelContext.insert(ScheduleRuleModel(from: rule))
        }
        try? modelContext.save()
    }

    // MARK: - Replace All (Reset)

    public func replaceAll(definitions: [ShiftDefinition], rules: [ScheduleRule]) {
        // Delete existing config models. WorkDays are a DIFFERENT model and
        // are NOT touched — historical snapshots remain intact.
        for model in fetchAllDefinitionModels() { modelContext.delete(model) }
        for model in fetchAllRuleModels() { modelContext.delete(model) }
        for def in definitions { modelContext.insert(ShiftDefinitionModel(from: def)) }
        for rule in rules { modelContext.insert(ScheduleRuleModel(from: rule)) }
        try? modelContext.save()
    }

    // MARK: - Private Helpers

    private func fetchDefinitionModel(id: UUID) -> ShiftDefinitionModel? {
        let descriptor = FetchDescriptor<ShiftDefinitionModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchRuleModel(id: UUID) -> ScheduleRuleModel? {
        let descriptor = FetchDescriptor<ScheduleRuleModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchAllDefinitionModels() -> [ShiftDefinitionModel] {
        (try? modelContext.fetch(FetchDescriptor<ShiftDefinitionModel>())) ?? []
    }

    private func fetchAllRuleModels() -> [ScheduleRuleModel] {
        (try? modelContext.fetch(FetchDescriptor<ScheduleRuleModel>())) ?? []
    }
}
