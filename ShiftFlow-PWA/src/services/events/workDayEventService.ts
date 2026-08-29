import type { ReminderOffset, WorkDayEvent } from "@/domain/models/models";
import { nowISO } from "@/domain/resolver/datetime";
import { newId } from "@/services/id";
import { WorkDayEventRepository } from "@/storage/repositories/repositories";

export interface EventInput {
  title: string;
  startTime: string;
  endTime: string;
  reminderEnabled: boolean;
  reminderOffset: ReminderOffset | null;
}

export class WorkDayEventService {
  constructor(private events: WorkDayEventRepository) {}

  async forWorkDay(workDayID: string): Promise<WorkDayEvent[]> {
    return (await this.events.forWorkDay(workDayID)).sort((a, b) =>
      a.startTime.localeCompare(b.startTime),
    );
  }

  async replaceForWorkDay(
    workDayID: string,
    inputs: EventInput[],
  ): Promise<void> {
    const existing = await this.events.forWorkDay(workDayID);
    for (const event of existing) await this.events.delete(event.id);
    for (const input of inputs) await this.create(workDayID, input);
  }

  async deleteForWorkDay(workDayID: string): Promise<void> {
    await this.events.deleteForWorkDay(workDayID);
  }

  private async create(
    workDayID: string,
    input: EventInput,
  ): Promise<WorkDayEvent> {
    const now = nowISO();
    const event: WorkDayEvent = {
      id: newId(),
      workDayID,
      title: input.title.trim(),
      startTime: input.startTime,
      endTime: input.endTime,
      reminderEnabled: input.reminderEnabled,
      reminderOffset: input.reminderEnabled ? input.reminderOffset : null,
      createdAt: now,
      modifiedAt: now,
    };
    await this.events.put(event);
    return event;
  }
}
