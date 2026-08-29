// ShiftFlow PWA — UI
// ui/screens/upcomingScreen.ts
//
// "Tổng quan" — VIEW ONLY. Shows the next THREE calendar days (today, tomorrow,
// day after) read directly from the single source of truth (WorkDay +
// WorkDayTask). Tasks shown are exactly the VISIBLE assignments — Overview has
// NO visibility preference of its own; it reflects whatever was configured in
// Calendar/Day Detail.
//
// No edit/delete/toggle here. To change anything the user goes to the Lịch tab.
// No CTA buttons: the 3 days are already shown, and Calendar is a bottom tab.

import { app } from "@/services/appContainer";
import { el } from "@/ui/components/dom";
import type { ScreenContext } from "@/ui/navigation/router";
import {
  buildShiftColorMap,
  longDate,
  shiftBadge,
  timeFromISO,
  type ShiftColorMap,
} from "@/ui/components/format";
import { startOfLocalDay } from "@/domain/resolver/datetime";
import type { WorkDay } from "@/domain/models/models";

export async function renderUpcoming(_ctx: ScreenContext): Promise<HTMLElement> {
  const base = startOfLocalDay(new Date());
  const colors = buildShiftColorMap(await app.configService.allShifts());

  // Exactly the next 3 calendar days: today, tomorrow, day after.
  const days: { heading: string; date: Date; size: "md" | "lg" }[] = [
    { heading: "Hôm nay", date: dayOffset(base, 0), size: "lg" },
    { heading: "Ngày mai", date: dayOffset(base, 1), size: "md" },
    { heading: "Ngày kia", date: dayOffset(base, 2), size: "md" },
  ];

  const blocks = await Promise.all(
    days.map((d) => dayBlock(d.heading, d.date, colors, d.size)),
  );

  return el("div", { class: "screen" }, [
    el("div", { class: "app-title", text: "ShiftFlow" }),
    el("h1", { class: "screen-title", text: "Tổng quan" }),
    el("div", { class: "screen-subtitle", text: "Lịch làm việc của bạn" }),
    ...blocks,
  ]);
}

function dayOffset(base: Date, n: number): Date {
  return new Date(base.getFullYear(), base.getMonth(), base.getDate() + n);
}

async function dayBlock(
  heading: string,
  d: Date,
  colors: ShiftColorMap,
  size: "md" | "lg",
): Promise<HTMLElement> {
  const w = await app.workDayService.byDate(d);
  // Read the SAME visibility source of truth Calendar/Day Detail write to.
  const visibleTaskCodes = w
    ? (await app.taskService.visibleTasksForWorkDay(w.id)).map((t) => t.code)
    : [];

  // Quiet date heading (not a loud uppercase overline): "Hôm nay" + date below.
  return el("div", { class: "stack", style: "gap:8px;margin-bottom:18px" }, [
    el("div", { class: "day-heading" }, [
      el("span", { class: "day-heading-label", text: heading }),
      el("span", { class: "day-heading-date", text: `· ${longDate(d)}` }),
    ]),
    shiftCard({ w, visibleTaskCodes, colors, size }),
  ]);
}

interface CardArgs {
  w: WorkDay | undefined;
  visibleTaskCodes: string[];
  colors: ShiftColorMap;
  size: "md" | "lg";
}

function shiftCard(a: CardArgs): HTMLElement {
  const { w, visibleTaskCodes, colors, size } = a;
  const timeSize = size === "lg" ? "font-size:22px" : "font-size:18px";

  // Hierarchy: shift badge · time · tasks · note. A FIXED badge column ("wd-card"
  // grid) guarantees the content column starts at the same X for every card,
  // regardless of the shift code text. Note only renders when present.
  const badgeCol = el("div", { class: "wd-badge-col" }, [
    shiftBadge(w ? w.shiftCode : "OFF", colors, { size }),
  ]);

  const content = w
    ? el("div", { class: "stack wd-content", style: "gap:6px" }, [
        el("div", { class: "time", style: timeSize, text: `${timeFromISO(w.resolvedStartDateTime)} – ${timeFromISO(w.resolvedEndDateTime)}` }),
        visibleTaskCodes.length
          ? el("div", { class: "chips" },
              visibleTaskCodes.map((c) => el("span", { class: "chip readonly", text: c })))
          : null,
        w.note ? el("div", { class: "note-line", text: w.note }) : null,
      ])
    : el("div", { class: "stack wd-content", style: "gap:4px" }, [
        el("div", { class: "time", style: timeSize, text: "Nghỉ" }),
        el("div", { class: "muted", text: "Không có ca làm" }),
      ]);

  // VIEW ONLY: no click handler, no edit affordance.
  return el("div", { class: `card wd-card wd-card-${size}` }, [badgeCol, content]);
}
