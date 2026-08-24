// ShiftFlow — Application Layer
// ViewModels/ShiftSettingsViewModel.swift
//
// TASK-SETTINGS-001: ViewModel for the Settings / Shift Configuration screen.
//
// Coordinates ShiftConfigurationService for the UI. Contains NO shift-resolution
// logic and NEVER recalculates historical WorkDays.

import Foundation
import SwiftUI
import ShiftFlowDomain

/// ViewModel backing the Settings shift/rule configuration UI.
@Observable
public final class ShiftSettingsViewModel {

    // MARK: - Published State

    public var shifts: [ShiftDefinition] = []
    public var rules: [ScheduleRule] = []
    public var errorMessage: String?
    public var showResetConfirmation: Bool = false

    /// Default reminder preference (persisted at app-settings level in future).
    public var defaultReminderOffset: ReminderOffset = .twoHoursBefore

    // MARK: - Dependencies

    private let configurationService: ShiftConfigurationService

    public init(configurationService: ShiftConfigurationService) {
        self.configurationService = configurationService
        reload()
    }

    // MARK: - Load

    public func reload() {
        shifts = configurationService.allShifts()
        rules = configurationService.allRules()
    }

    // MARK: - Edit Shift

    /// Saves an edited shift. Returns true on success.
    public func saveShift(_ updated: ShiftDefinition) -> Bool {
        errorMessage = nil
        do {
            try configurationService.updateShift(updated)
            reload()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    /// Toggles a shift's active state. Historical WorkDays are unaffected.
    public func setShiftActive(code: String, isActive: Bool) -> Bool {
        errorMessage = nil
        do {
            try configurationService.setShiftActive(code: code, isActive: isActive)
            reload()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    // MARK: - Edit Rule

    public func saveRule(_ updated: ScheduleRule) -> Bool {
        errorMessage = nil
        do {
            try configurationService.updateRule(updated)
            reload()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    public func setRuleActive(id: UUID, isActive: Bool) -> Bool {
        errorMessage = nil
        do {
            try configurationService.setRuleActive(id: id, isActive: isActive)
            reload()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    // MARK: - Reset

    /// Restores defaults after confirmation. Historical WorkDays are unaffected.
    public func confirmReset() {
        configurationService.resetToDefaults()
        reload()
    }

    // MARK: - Helpers

    /// The C5 special rule (if present) for display.
    public var c5Rule: ScheduleRule? {
        guard let c5 = shifts.first(where: { $0.code == "C5" }) else { return nil }
        return rules.first { $0.shiftID == c5.id }
    }
}
