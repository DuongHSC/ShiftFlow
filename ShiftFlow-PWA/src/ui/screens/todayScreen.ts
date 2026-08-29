// ShiftFlow PWA — UI
// ui/screens/todayScreen.ts
//
// Legacy "Hôm nay" screen. Not a bottom-nav tab anymore (the "Tổng quan" home
// covers today + tomorrow), but kept reachable via #today and used by tests.
// Migrated to the color-driven shift badge.

import { app } from "@/services/appContainer";
import { el } from "@/ui/components/dom";
import type { ScreenContext } from "@/ui/navigation/router";
import {
  buildShiftColorMap,
  longDate,
  shiftBadge,
  timeFromISO,
  weekdayFull,
  type ShiftColorMap,
} from "@/ui/components/format";
import {
  fromISODateLocal,
  startOfLocalDay,
  toISODateLocal,
} from "@/domain/resolver/datetime";
import { openDayDetail } from "./dayDetailSheet";
import type { WorkDay } from "@/domain/models/models";

export async function renderToday(ctx: ScreenContext): Promise<HTMLElement> {
  const today = startOfLocalDay(new Date());
  const isoToday = toISODateLocal(today);
  const colors = buildShiftColorMap(await app.configService.allShifts());
  const workDay = await app.workDayService.byDate(today);

  const all = (await app.workDayService.all())
    .filter((w) => w.date > isoToday)
    .sort((a, b) => a.date.localeCompare(b.date));
  const next = all[0];

  const tasks = workDay ? await app.taskService.visibleTasksForWorkDay(workDay.id) : [];
  const openToday = () => openDayDetail(isoToday, ctx.refresh);

  return el("div", { class: "screen" }, [
    el("div", { class: "app-title", text: "ShiftFlow" }),
    el("h1", { class: "screen-title", text: "Hôm nay" }),
    el("div", { class: "screen-subtitle", text: longDate(today) }),

    workDay
      ? shiftCard(workDay, tasks.map((t) => t.code), colors, openToday)
      : offCard(colors, openToday),

    el("div", { class: "section-label", text: "Ca kế tiếp" }),
    next
      ? nextCard(next, colors)
      : el("div", { class: "empty-state", text: "Chưa có ca nào sắp tới." }),
  ]);
}

function shiftCard(
  w: WorkDay,
  taskCodes: string[],
  colors: ShiftColorMap,
  onOpen: () => void,
): HTMLElement {
  return el("div", { class: "card tap", onClick: onOpen }, [
    el("div", { class: "row", style: "align-items:center" }, [
      shiftBadge(w.shiftCode, colors, { size: "lg" }),
      el("div", { class: "stack", style: "flex:1;margin-left:14px;gap:4px" }, [
        el("div", { class: "time", style: "font-size:22px", text: `${timeFromISO(w.resolvedStartDateTime)} – ${timeFromISO(w.resolvedEndDateTime)}` }),
        el("div", { class: "muted", text: taskCodes.length ? taskCodes.join(", ") : "Không có task" }),
        w.note ? el("div", { class: "tiny note-line", text: w.note }) : null,
      ]),
    ]),
  ]);
}

function offCard(colors: ShiftColorMap, onOpen: () => void): HTMLElement {
  return el("div", { class: "card tap", onClick: onOpen }, [
    el("div", { class: "row", style: "align-items:center" }, [
      shiftBadge("OFF", colors, { size: "lg" }),
      el("div", { class: "stack", style: "flex:1;margin-left:14px;gap:4px" }, [
        el("div", { class: "time", style: "font-size:22px", text: "Nghỉ" }),
        el("div", { class: "muted", text: "Không có ca làm hôm nay." }),
      ]),
    ]),
  ]);
}

function nextCard(w: WorkDay, colors: ShiftColorMap): HTMLElement {
  const d = fromISODateLocal(w.date);
  return el("div", { class: "card tight" }, [
    el("div", { class: "row" }, [
      el("div", { class: "row", style: "gap:12px" }, [
        shiftBadge(w.shiftCode, colors),
        el("div", { class: "stack" }, [
          el("div", { style: "font-weight:600", text: `${weekdayFull(d)}, ${d.getDate()}/${d.getMonth() + 1}` }),
          el("div", { class: "muted", text: `${timeFromISO(w.resolvedStartDateTime)}–${timeFromISO(w.resolvedEndDateTime)}` }),
        ]),
      ]),
    ]),
  ]);
}
