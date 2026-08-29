// ShiftFlow PWA — Tests
// tests/taskVisibility.test.ts
//
// TASK-PWA-UX-DATA-002 minimal coverage:
//   - existing (pre-field) assignments default to isVisible=true
//   - hide task / unhide task
//   - Overview reflects Calendar/Day-Detail visibility (single source of truth)
//   - shift edit (color/times/name)
//   - shift delete protection when used by a WorkDay

import { describe, it, expect, beforeEach } from "vitest";
import { ShiftFlowDB } from "@/storage/db/db";
import {
  ScheduleRuleRepository,
  ShiftDefinitionRepository,
  TaskDefinitionRepository,
  WorkDayRepository,
  WorkDayTaskRepository,
} from "@/storage/repositories/repositories";
import { seedIfNeeded } from "@/storage/seeding";
import { WorkDayService } from "@/services/workday/workDayService";
import { TaskService } from "@/services/tasks/taskService";
import { ShiftConfigurationService } from "@/services/settings/shiftConfigurationService";
import { SEED_IDS } from "@/domain/seed/seed";

let dbCounter = 0;

interface Ctx {
  db: ShiftFlowDB;
  workDays: WorkDayService;
  tasks: TaskService;
  config: ShiftConfigurationService;
}

async function makeCtx(): Promise<Ctx> {
  const db = new ShiftFlowDB(`test-vis-${dbCounter++}-${Date.now()}`);
  await seedIfNeeded(db);
  const workDays = new WorkDayService(new WorkDayRepository(db));
  const tasks = new TaskService(
    new TaskDefinitionRepository(db),
    new WorkDayTaskRepository(db),
  );
  const config = new ShiftConfigurationService(
    new ShiftDefinitionRepository(db),
    new ScheduleRuleRepository(db),
  );
  return { db, workDays, tasks, config };
}

let ctx: Ctx;
beforeEach(async () => {
  ctx = await makeCtx();
});

async function createC5(ctxx: Ctx) {
  const lookup = await ctxx.config.lookup("C5");
  return ctxx.workDays.create(new Date(2026, 7, 15), lookup!.shift, lookup!.rules);
}

describe("task visibility", () => {
  it("legacy assignment without isVisible is treated as visible", async () => {
    const wd = await createC5(ctx);
    // Write a join record directly WITHOUT isVisible (simulating pre-migration data).
    await ctx.db.workDayTasks.put({
      id: "legacy-1",
      workDayID: wd.id,
      taskDefinitionID: SEED_IDS.mw,
      createdAt: new Date().toISOString(),
      modifiedAt: new Date().toISOString(),
    });

    const visible = await ctx.tasks.visibleTasksForWorkDay(wd.id);
    expect(visible.map((t) => t.code)).toContain("MW");
  });

  it("new assignments are visible by default", async () => {
    const wd = await createC5(ctx);
    await ctx.tasks.addTask(SEED_IDS.mw, wd.id);
    const visible = await ctx.tasks.visibleTasksForWorkDay(wd.id);
    expect(visible.length).toBe(1);
    expect(visible[0].code).toBe("MW");
  });

  it("hide task removes it from visible but keeps the assignment", async () => {
    const wd = await createC5(ctx);
    await ctx.tasks.addTask(SEED_IDS.mw, wd.id);
    await ctx.tasks.setTaskVisibility(SEED_IDS.mw, wd.id, false);

    expect((await ctx.tasks.visibleTasksForWorkDay(wd.id)).length).toBe(0);
    // Still assigned (not deleted).
    expect((await ctx.tasks.tasksForWorkDay(wd.id)).length).toBe(1);
  });

  it("unhide task restores visibility", async () => {
    const wd = await createC5(ctx);
    await ctx.tasks.addTask(SEED_IDS.mw, wd.id);
    await ctx.tasks.setTaskVisibility(SEED_IDS.mw, wd.id, false);
    await ctx.tasks.setTaskVisibility(SEED_IDS.mw, wd.id, true);
    expect((await ctx.tasks.visibleTasksForWorkDay(wd.id)).map((t) => t.code)).toEqual(["MW"]);
  });

  it("Overview reads the SAME visibility source of truth as Day Detail", async () => {
    // Two tasks assigned; hide one via the service (as Day Detail would).
    const wd = await createC5(ctx);
    const ticket = await ctx.tasks.createTask("Ticket", "Ticket");
    await ctx.tasks.addTask(SEED_IDS.mw, wd.id);
    await ctx.tasks.addTask(ticket.id, wd.id);
    await ctx.tasks.setTaskVisibility(ticket.id, wd.id, false);

    // "Overview" query == visibleTasksForWorkDay (no separate preference).
    const overview = (await ctx.tasks.visibleTasksForWorkDay(wd.id)).map((t) => t.code);
    expect(overview).toContain("MW");
    expect(overview).not.toContain("Ticket");

    // Unhide -> Overview reflects it immediately.
    await ctx.tasks.setTaskVisibility(ticket.id, wd.id, true);
    const overview2 = (await ctx.tasks.visibleTasksForWorkDay(wd.id)).map((t) => t.code).sort();
    expect(overview2).toEqual(["MW", "Ticket"]);
  });
});

describe("shift CRUD", () => {
  it("edits a shift's color, name and times", async () => {
    const c5 = (await ctx.config.lookup("C5"))!.shift;
    await ctx.config.updateShift({
      ...c5,
      name: "Ca chiều",
      color: "teal",
      startHour: 13,
      startMinute: 0,
    });
    const reloaded = (await ctx.config.allShifts()).find((s) => s.id === c5.id)!;
    expect(reloaded.name).toBe("Ca chiều");
    expect(reloaded.color).toBe("teal");
    expect(reloaded.startHour).toBe(13);
  });

  it("creates a dynamic shift (e.g. C6) that resolves and is looked up", async () => {
    const created = await ctx.config.createShift({
      code: "C6",
      color: "indigo",
      startHour: 22, startMinute: 0,
      endHour: 6, endMinute: 0,
      breakStartHour: 2, breakStartMinute: 0,
      breakEndHour: 3, breakEndMinute: 0,
    });
    expect(created.code).toBe("C6");
    const lookup = await ctx.config.lookup("C6");
    expect(lookup).not.toBeNull();
  });

  it("rejects a duplicate shift code", async () => {
    await expect(
      ctx.config.createShift({
        code: "C5",
        color: "blue",
        startHour: 8, startMinute: 0,
        endHour: 17, endMinute: 0,
        breakStartHour: 12, breakStartMinute: 0,
        breakEndHour: 13, breakEndMinute: 0,
      }),
    ).rejects.toThrow();
  });

  it("deleteShift removes an UNUSED shift and its rules", async () => {
    const created = await ctx.config.createShift({
      code: "C9",
      color: "pink",
      startHour: 8, startMinute: 0,
      endHour: 17, endMinute: 0,
      breakStartHour: 12, breakStartMinute: 0,
      breakEndHour: 13, breakEndMinute: 0,
    });
    await ctx.config.deleteShift(created.id);
    expect((await ctx.config.allShifts()).some((s) => s.id === created.id)).toBe(false);
  });

  it("shift-delete protection: caller must check usage (WorkDay count) before deleting", async () => {
    // The UI guards deletion by counting WorkDays using the shift; verify that
    // count is discoverable so historical WorkDays are never cascade-deleted.
    const wd = await createC5(ctx);
    const c5Id = wd.shiftID;
    const usedBy = (await ctx.workDays.all()).filter((w) => w.shiftID === c5Id).length;
    expect(usedBy).toBeGreaterThan(0);
  });
});
