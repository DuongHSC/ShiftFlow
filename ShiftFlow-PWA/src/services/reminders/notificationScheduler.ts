import type { ShiftFlowDB } from "@/storage/db/db";
import type { ReminderOffset, WorkDayTask } from "@/domain/models/models";
import { dateTimeOnLocalDay, fromISODateLocal } from "@/domain/resolver/datetime";
import { offsetMillis } from "@/domain/resolver/reminderTiming";

const MAX_TIMEOUT_MS = 2_147_483_647;

export interface TaskReminder {
  id: string;
  title: string;
  body: string;
  fireDate: Date;
}

export function taskReminderFireDate(
  workDayDateISO: string,
  startTime: string,
  offset: ReminderOffset,
): Date | null {
  const match = /^(\d{2}):(\d{2})$/.exec(startTime);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return null;
  const start = dateTimeOnLocalDay(fromISODateLocal(workDayDateISO), hour, minute);
  return new Date(start.getTime() + offsetMillis(offset));
}

export class NotificationScheduler {
  private timers = new Map<string, number>();

  constructor(private db: ShiftFlowDB) {}

  async start(): Promise<void> {
    if (!this.supported()) return;
    await this.reschedule();
  }

  async requestPermission(): Promise<NotificationPermission> {
    if (!this.supported()) return "denied";
    if (Notification.permission !== "default") return Notification.permission;
    return Notification.requestPermission();
  }

  async reschedule(): Promise<void> {
    this.clear();
    if (!this.supported() || Notification.permission !== "granted") return;
    const reminders = await this.upcomingTaskReminders(new Date());
    for (const reminder of reminders) {
      const delay = reminder.fireDate.getTime() - Date.now();
      if (delay < 0 || delay > MAX_TIMEOUT_MS) continue;
      const timer = window.setTimeout(() => {
        new Notification(reminder.title, { body: reminder.body, tag: reminder.id });
        this.timers.delete(reminder.id);
      }, delay);
      this.timers.set(reminder.id, timer);
    }
  }

  clear(): void {
    for (const timer of this.timers.values()) window.clearTimeout(timer);
    this.timers.clear();
  }

  async upcomingTaskReminders(now: Date): Promise<TaskReminder[]> {
    const [workDays, taskDefinitions, assignments] = await Promise.all([
      this.db.workDays.toArray(),
      this.db.taskDefinitions.toArray(),
      this.db.workDayTasks.toArray(),
    ]);
    const workDayById = new Map(workDays.map((w) => [w.id, w]));
    const taskById = new Map(taskDefinitions.map((t) => [t.id, t]));
    const out: TaskReminder[] = [];

    for (const assignment of assignments) {
      const reminder = this.buildTaskReminder(assignment);
      if (!reminder) continue;
      const workDay = workDayById.get(assignment.workDayID);
      const task = taskById.get(assignment.taskDefinitionID);
      if (!workDay || !task) continue;

      const fireDate = taskReminderFireDate(
        workDay.date,
        reminder.startTime,
        reminder.offset,
      );
      if (!fireDate || fireDate <= now) continue;
      out.push({
        id: assignment.id,
        title: task.code,
        body: `${task.name} lúc ${reminder.startTime}${reminder.endTime ? `–${reminder.endTime}` : ""}`,
        fireDate,
      });
    }

    return out.sort((a, b) => a.fireDate.getTime() - b.fireDate.getTime());
  }

  private supported(): boolean {
    return typeof window !== "undefined" && "Notification" in window;
  }

  private buildTaskReminder(
    assignment: WorkDayTask,
  ): { startTime: string; endTime: string; offset: ReminderOffset } | null {
    if (!assignment.reminderEnabled || !assignment.startTime) return null;
    return {
      startTime: assignment.startTime,
      endTime: assignment.endTime ?? "",
      offset: assignment.reminderOffset ?? "30min",
    };
  }
}

