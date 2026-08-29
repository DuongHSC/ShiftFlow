// ShiftFlow PWA — Services
// services/appContainer.ts
//
// Composition root. Wires repositories + services over the Dexie DB.
// Mirrors the iOS AppContainer at a conceptual level (UI -> services -> domain
// -> storage). UI code depends only on this container's services.

import { ShiftFlowDB, db as sharedDb } from "@/storage/db/db";
import {
  ReminderRepository,
  ScheduleRuleRepository,
  ShiftDefinitionRepository,
  TaskDefinitionRepository,
  WorkDayRepository,
  WorkDayTaskRepository,
} from "@/storage/repositories/repositories";
import { seedIfNeeded } from "@/storage/seeding";
import { WorkDayService } from "@/services/workday/workDayService";
import { TaskService } from "@/services/tasks/taskService";
import { ReminderService } from "@/services/reminders/reminderService";
import { ShiftConfigurationService } from "@/services/settings/shiftConfigurationService";
import { CsvService } from "@/import-export/csv/csvService";

export class AppContainer {
  readonly db: ShiftFlowDB;
  readonly workDayService: WorkDayService;
  readonly taskService: TaskService;
  readonly reminderService: ReminderService;
  readonly configService: ShiftConfigurationService;
  readonly csvService: CsvService;

  constructor(db: ShiftFlowDB = sharedDb) {
    this.db = db;

    const workDayRepo = new WorkDayRepository(db);
    const shiftRepo = new ShiftDefinitionRepository(db);
    const ruleRepo = new ScheduleRuleRepository(db);
    const taskDefRepo = new TaskDefinitionRepository(db);
    const assignRepo = new WorkDayTaskRepository(db);
    const reminderRepo = new ReminderRepository(db);

    this.configService = new ShiftConfigurationService(shiftRepo, ruleRepo);
    this.workDayService = new WorkDayService(workDayRepo);
    this.taskService = new TaskService(taskDefRepo, assignRepo);
    this.reminderService = new ReminderService(reminderRepo);
    this.csvService = new CsvService(
      this.workDayService,
      this.taskService,
      this.configService,
    );
  }

  /** Idempotent first-run seed (C1..C5 + C5 rule + MW). */
  async bootstrap(): Promise<void> {
    await seedIfNeeded(this.db);
  }
}

/** The shared application container (used by the UI). */
export const app = new AppContainer();
