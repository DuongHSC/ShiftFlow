// ShiftFlow PWA — Storage Layer
// storage/db/db.ts
//
// Dexie schema. IndexedDB is the source of truth (local-first, offline).
// Object stores mirror the iOS SwiftData persistent models:
//   WorkDayModel, ShiftDefinitionModel, ScheduleRuleModel,
//   TaskDefinitionModel, WorkDayTaskModel
// plus ReminderConfiguration (persisted preference in the PWA).
//
// "One WorkDay per date" is enforced at the service layer (as on iOS), backed
// here by a unique index on WorkDay.date.

import Dexie, { type Table } from "dexie";
import type {
  ReminderConfiguration,
  ScheduleRule,
  ShiftDefinition,
  TaskDefinition,
  WorkDay,
  WorkDayTask,
} from "@/domain/models/models";

export class ShiftFlowDB extends Dexie {
  workDays!: Table<WorkDay, string>;
  shiftDefinitions!: Table<ShiftDefinition, string>;
  scheduleRules!: Table<ScheduleRule, string>;
  taskDefinitions!: Table<TaskDefinition, string>;
  workDayTasks!: Table<WorkDayTask, string>;
  reminders!: Table<ReminderConfiguration, string>;

  constructor(name = "shiftflow") {
    super(name);
    // v1: original stores.
    this.version(1).stores({
      // &date -> unique index (one WorkDay per calendar date).
      workDays: "id, &date, shiftID, modifiedAt",
      shiftDefinitions: "id, code, isActive",
      scheduleRules: "id, shiftID, priority, isActive",
      taskDefinitions: "id, code, isActive",
      workDayTasks: "id, workDayID, taskDefinitionID",
      reminders: "id, workDayID",
    });

    // v2: adds task-assignment visibility. Index shape is unchanged (isVisible
    // is not indexed), but we bump the version to run a safe upgrade that
    // backfills existing WorkDayTask records with isVisible = true. Existing
    // user data is preserved — no store is cleared or recreated.
    this.version(2)
      .stores({
        workDays: "id, &date, shiftID, modifiedAt",
        shiftDefinitions: "id, code, isActive",
        scheduleRules: "id, shiftID, priority, isActive",
        taskDefinitions: "id, code, isActive",
        workDayTasks: "id, workDayID, taskDefinitionID",
        reminders: "id, workDayID",
      })
      .upgrade(async (tx) => {
        await tx
          .table("workDayTasks")
          .toCollection()
          .modify((wt: { isVisible?: boolean }) => {
            if (wt.isVisible === undefined) wt.isVisible = true;
          });
      });
  }
}

/** The shared application database instance. */
export const db = new ShiftFlowDB();
