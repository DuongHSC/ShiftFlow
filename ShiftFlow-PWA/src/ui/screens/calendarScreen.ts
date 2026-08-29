// ShiftFlow PWA — UI
// ui/screens/calendarScreen.ts
//
// Month calendar (Monday-first). Cells show the shift CODE tinted with the
// shift's configured color (from shiftDefinitions — no C1..C5 hard-coding),
// plus task/note dots. TODAY and SELECTED are visually DISTINCT states and can
// combine. A detail card for the selected day appears below the grid with a
// "Chi tiết / Sửa" action. Calendar data logic (reads) is unchanged.

import { app } from "@/services/appContainer";
import { el } from "@/ui/components/dom";
import type { ScreenContext } from "@/ui/navigation/router";
import {
  buildShiftColorMap,
  colorForCode,
  longDate,
  monthName,
  shiftBadge,
  timeFromISO,
  type ShiftColorMap,
} from "@/ui/components/format";
import {
  fromISODateLocal,
  startOfLocalDay,
  toISODateLocal,
} from "@/domain/resolver/datetime";
import { openDayDetail } from "./dayDetailSheet";
import type { WorkDay } from "@/domain/models/models";

// Module-level view state (persists across re-renders within a session).
let viewYear = new Date().getFullYear();
let viewMonth = new Date().getMonth(); // 0-based
let selectedISO: string | null = null;

const WEEKDAY_LABELS = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]; // Monday-first

export async function renderCalendar(ctx: ScreenContext): Promise<HTMLElement> {
  const first = new Date(viewYear, viewMonth, 1);
  const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
  const jsDow = first.getDay();
  const leading = (jsDow + 6) % 7; // Monday-first offset

  const colors = buildShiftColorMap(await app.configService.allShifts());
  const workDays = await app.workDayService.byDateRange(
    new Date(viewYear, viewMonth, 1),
    new Date(viewYear, viewMonth, daysInMonth),
  );
  const byDate = new Map<string, WorkDay>(workDays.map((w) => [w.date, w]));
  const todayISO = toISODateLocal(startOfLocalDay(new Date()));

  // Visible task codes per WorkDay in this month (single source of truth), for
  // compact in-cell display.
  const visibleTaskCodes = new Map<string, string[]>();
  for (const w of workDays) {
    const codes = (await app.taskService.visibleTasksForWorkDay(w.id)).map((t) => t.code);
    if (codes.length) visibleTaskCodes.set(w.id, codes);
  }

  const selectedWorkDay = selectedISO
    ? byDate.get(selectedISO) ??
      (await app.workDayService.byDate(fromISODateLocal(selectedISO)))
    : undefined;
  const selectedTaskCodes = selectedWorkDay
    ? (await app.taskService.visibleTasksForWorkDay(selectedWorkDay.id)).map((t) => t.code)
    : [];

  const grid = el("div", { class: "cal-grid" }, [
    ...WEEKDAY_LABELS.map((w) => el("div", { class: "cal-weekday", text: w })),
    ...Array.from({ length: leading }, () => el("div", { class: "cal-cell empty" })),
    ...Array.from({ length: daysInMonth }, (_, i) => {
      const day = i + 1;
      const iso = toISODateLocal(new Date(viewYear, viewMonth, day));
      const w = byDate.get(iso);
      const isToday = iso === todayISO;
      const isSelected = iso === selectedISO;
      const tint = w ? colorForCode(w.shiftCode, colors) : undefined;

      return el(
        "button",
        {
          class: `cal-cell${isToday ? " today" : ""}${isSelected ? " selected" : ""}`,
          "aria-label": `Ngày ${day}${w ? `, ca ${w.shiftCode}` : ", OFF"}${isToday ? ", hôm nay" : ""}${isSelected ? ", đang chọn" : ""}`,
          "aria-pressed": isSelected ? "true" : "false",
          // Single click/tap = SELECT ONLY (shows the summary below).
          onClick: () => {
            selectedISO = iso;
            ctx.refresh();
          },
          // Double click/tap = open Day Detail in VIEW mode.
          onDblclick: () => {
            selectedISO = iso;
            void openDayDetail(iso, ctx.refresh, { mode: "view" });
          },
        },
        [
          el("span", { class: "daynum", text: String(day) }),
          w
            ? el("span", {
                class: "cell-code",
                style: `color:${tint}`,
                text: w.shiftCode,
              })
            : el("span", { class: "cell-code off-code", text: "OFF" }),
          w
            ? cellTasks(visibleTaskCodes.get(w.id) ?? [])
            : el("span", { class: "cell-tasks" }),
        ],
      );
    }),
  ]);

  return el("div", { class: "screen" }, [
    el("div", { class: "app-title", text: "ShiftFlow" }),
    el("h1", { class: "screen-title", text: "Lịch" }),
    el("div", { class: "cal-header" }, [
      el("div", { style: "font-weight:700;font-size:18px", text: `${monthName(viewMonth)}, ${viewYear}` }),
      el("div", { class: "cal-nav" }, [
        el("button", { class: "btn icon-btn", text: "‹", "aria-label": "Tháng trước", onClick: () => step(-1, ctx) }),
        el("button", { class: "btn", text: "Hôm nay", onClick: () => goToday(ctx) }),
        el("button", { class: "btn icon-btn", text: "›", "aria-label": "Tháng sau", onClick: () => step(1, ctx) }),
      ]),
    ]),
    el("div", { class: "card" }, [grid]),
    el("div", { class: "cal-legend tiny" }, [
      el("span", { text: "● Hôm nay · ▭ Đang chọn · Chạm 2 lần để xem" }),
    ]),
    selectedISO
      ? selectedDetailCard(selectedISO, selectedWorkDay, selectedTaskCodes, colors, ctx)
      : el("div", { class: "empty-state", text: "Chọn một ngày để xem chi tiết." }),
  ]);
}

/** Compact per-cell visible tasks: up to 2 codes, then a "+N" overflow chip. */
function cellTasks(codes: string[]): HTMLElement {
  if (!codes.length) return el("span", { class: "cell-tasks" });
  const shown = codes.slice(0, 2);
  const extra = codes.length - shown.length;
  return el(
    "span",
    { class: "cell-tasks" },
    [
      ...shown.map((c) => el("span", { class: "cell-task", text: c })),
      extra > 0 ? el("span", { class: "cell-task more", text: `+${extra}` }) : null,
    ],
  );
}

function selectedDetailCard(
  iso: string,
  w: WorkDay | undefined,
  taskCodes: string[],
  colors: ShiftColorMap,
  ctx: ScreenContext,
): HTMLElement {
  const d = fromISODateLocal(iso);
  return el("div", { class: "card" }, [
    el("div", { style: "font-weight:700;margin-bottom:10px", text: longDate(d) }),
    w
      ? el("div", { class: "row", style: "align-items:center" }, [
          shiftBadge(w.shiftCode, colors, { size: "md" }),
          el("div", { class: "stack", style: "flex:1;margin-left:12px;gap:3px" }, [
            el("div", { class: "time", style: "font-size:18px", text: `${timeFromISO(w.resolvedStartDateTime)} – ${timeFromISO(w.resolvedEndDateTime)}` }),
            el("div", { class: "muted", text: taskCodes.length ? `Task: ${taskCodes.join(", ")}` : "Không có task" }),
            el("div", { class: "muted", text: w.note ? `Ghi chú: ${w.note}` : "Không có ghi chú" }),
          ]),
        ])
      : el("div", { class: "row", style: "align-items:center" }, [
          shiftBadge("OFF", colors, { size: "md" }),
          el("div", { class: "stack", style: "flex:1;margin-left:12px;gap:3px" }, [
            el("div", { class: "time", style: "font-size:18px", text: "Nghỉ" }),
            el("div", { class: "muted", text: "Không có ca làm" }),
          ]),
        ]),
    el("div", { class: "btn-row", style: "margin-top:12px" }, [
      el("button", {
        class: "btn block",
        text: "Xem chi tiết",
        onClick: () => void openDayDetail(iso, ctx.refresh, { mode: "view" }),
      }),
      el("button", {
        class: "btn primary block",
        text: w ? "Sửa" : "Thêm ca",
        onClick: () => void openDayDetail(iso, ctx.refresh, { mode: "edit" }),
      }),
    ]),
  ]);
}

function step(delta: number, ctx: ScreenContext): void {
  viewMonth += delta;
  if (viewMonth < 0) {
    viewMonth = 11;
    viewYear -= 1;
  } else if (viewMonth > 11) {
    viewMonth = 0;
    viewYear += 1;
  }
  ctx.refresh();
}

function goToday(ctx: ScreenContext): void {
  const now = new Date();
  viewYear = now.getFullYear();
  viewMonth = now.getMonth();
  selectedISO = toISODateLocal(startOfLocalDay(now));
  ctx.refresh();
}
