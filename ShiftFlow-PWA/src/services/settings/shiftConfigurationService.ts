// ShiftFlow PWA — Services
// services/settings/shiftConfigurationService.ts
//
// User-editable shift definitions and schedule rules, plus the shift lookup
// used by resolution (mirrors iOS ShiftConfigurationService + ShiftDefinitionProvider).
//
// Editing configuration affects FUTURE WorkDay resolution only. It never
// rewrites existing WorkDay snapshots (that invariant is enforced in
// WorkDayService — config edits here simply do not touch WorkDays).

import type {
  ScheduleRule,
  ShiftColor,
  ShiftDefinition,
} from "@/domain/models/models";
import {
  ScheduleRuleRepository,
  ShiftDefinitionRepository,
} from "@/storage/repositories/repositories";
import { nowISO } from "@/domain/resolver/datetime";
import { newId } from "@/services/id";

export interface ShiftLookupResult {
  shift: ShiftDefinition;
  rules: ScheduleRule[];
}

export class ShiftConfigError extends Error {
  constructor(
    public code: "emptyCode" | "duplicateCode",
    message: string,
  ) {
    super(message);
    this.name = "ShiftConfigError";
  }
}

export interface NewShiftInput {
  code: string;
  name?: string;
  color: ShiftColor;
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
  breakStartHour: number;
  breakStartMinute: number;
  breakEndHour: number;
  breakEndMinute: number;
}

export class ShiftConfigurationService {
  constructor(
    private shifts: ShiftDefinitionRepository,
    private rules: ScheduleRuleRepository,
  ) {}

  allShifts(): Promise<ShiftDefinition[]> {
    return this.shifts.all();
  }

  allRules(): Promise<ScheduleRule[]> {
    return this.rules.all();
  }

  async activeShifts(): Promise<ShiftDefinition[]> {
    return (await this.shifts.all())
      .filter((s) => s.isActive)
      .sort((a, b) => a.code.localeCompare(b.code));
  }

  /** Resolve a shift code to its definition and applicable rules. */
  async lookup(code: string): Promise<ShiftLookupResult | null> {
    const normalized = code.trim().toUpperCase();
    const shift = (await this.shifts.all()).find(
      (s) => s.code.toUpperCase() === normalized,
    );
    if (!shift) return null;
    const rules = (await this.rules.all()).filter((r) => r.shiftID === shift.id);
    return { shift, rules };
  }

  /** Updates a shift's editable fields. Code/id are stable. */
  async updateShift(updated: ShiftDefinition): Promise<void> {
    await this.shifts.put({ ...updated, modifiedAt: nowISO() });
  }

  /**
   * Creates a NEW shift definition (e.g. C6, C7, "Ca đêm"). Additive only — does
   * not touch existing shifts, WorkDays, or resolution behavior. Rejects an
   * empty or duplicate code.
   */
  async createShift(input: NewShiftInput): Promise<ShiftDefinition> {
    const code = input.code.trim();
    if (!code) throw new ShiftConfigError("emptyCode", "Mã ca không được để trống");
    const existing = await this.shifts.all();
    if (existing.some((s) => s.code.toUpperCase() === code.toUpperCase())) {
      throw new ShiftConfigError("duplicateCode", `Mã ca đã tồn tại: ${code}`);
    }
    const now = nowISO();
    const shift: ShiftDefinition = {
      id: newId(),
      code,
      name: (input.name && input.name.trim()) || code,
      startHour: input.startHour,
      startMinute: input.startMinute,
      endHour: input.endHour,
      endMinute: input.endMinute,
      breakStartHour: input.breakStartHour,
      breakStartMinute: input.breakStartMinute,
      breakEndHour: input.breakEndHour,
      breakEndMinute: input.breakEndMinute,
      color: input.color,
      isActive: true,
      createdAt: now,
      modifiedAt: now,
    };
    await this.shifts.put(shift);
    return shift;
  }

  /** Updates a schedule rule's editable fields. id/shiftID stable. */
  async updateRule(updated: ScheduleRule): Promise<void> {
    await this.rules.put({ ...updated, modifiedAt: nowISO() });
  }

  /**
   * Deletes a shift definition and its associated schedule rules.
   *
   * The caller MUST verify the shift is not in use by any WorkDay first
   * (historical WorkDays must never be cascade-deleted). This method does not
   * touch WorkDays. Rules belonging to the shift are removed alongside it.
   */
  async deleteShift(id: string): Promise<void> {
    const rules = (await this.rules.all()).filter((r) => r.shiftID === id);
    for (const r of rules) await this.rules.delete(r.id);
    await this.shifts.delete(id);
  }
}
