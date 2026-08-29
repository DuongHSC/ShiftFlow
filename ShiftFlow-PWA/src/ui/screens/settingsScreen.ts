// ShiftFlow PWA — UI
// ui/screens/settingsScreen.ts
//
// Settings home + sub-screens:
//   - Cấu hình ca: COMPACT list of shifts (rendered from shiftDefinitions, no
//     C1..C5 hard-coding) → shift editor (times + color) and "+ Thêm ca".
//   - Quản lý công việc: compact task list → task editor + add.
//   - Nhắc nhở / Giao diện: disabled "Sắp có" (no fake functionality).
//   - Quản lý dữ liệu: opens Data Management (CSV/JSON export + import).
//   - Giới thiệu.
// UI only — consumes existing services (adds ShiftConfigurationService.createShift).

import { app } from "@/services/appContainer";
import { el, toast } from "@/ui/components/dom";
import type { ScreenContext } from "@/ui/navigation/router";
import { renderDataManagement } from "./dataManagementScreen";
import { paletteEntries, shiftDefinitionHex } from "@/domain/models/shiftColor";
import type { ShiftColor } from "@/domain/models/models";

type SettingsView =
  | "root"
  | "data"
  | "shifts"
  | "shiftEditor"
  | "tasks"
  | "taskEditor";

let view: SettingsView = "root";
let editingShiftId: string | null = null; // null in editor = "add new"
let editingTaskId: string | null = null;

/**
 * Resets Settings to its ROOT view. Called by the router when the user taps the
 * "Cài đặt" bottom tab, so entering Settings never lands on a stale sub-screen
 * (e.g. Dữ liệu) after visiting another tab. Sub-navigation within Settings
 * uses refresh() and therefore preserves the sub-view.
 */
export function resetSettingsView(): void {
  view = "root";
  editingShiftId = null;
  editingTaskId = null;
}

export async function renderSettings(ctx: ScreenContext): Promise<HTMLElement> {
  switch (view) {
    case "data":
      return renderDataManagement({
        back: () => go(ctx, "root"),
        refresh: ctx.refresh,
      });
    case "shifts":
      return renderShiftList(ctx);
    case "shiftEditor":
      return renderShiftEditor(ctx);
    case "tasks":
      return renderTaskList(ctx);
    case "taskEditor":
      return renderTaskEditor(ctx);
    default:
      return renderRoot(ctx);
  }
}

function go(ctx: ScreenContext, v: SettingsView): void {
  view = v;
  ctx.refresh();
}

// ---- Root ----

function renderRoot(ctx: ScreenContext): HTMLElement {
  const row = (
    icon: string,
    title: string,
    subtitle: string,
    onClick?: () => void,
    enabled = true,
  ) =>
    el(
      "div",
      {
        class: `list-row${enabled ? "" : " disabled"}`,
        role: "button",
        "aria-disabled": enabled ? "false" : "true",
        onClick: enabled ? onClick : undefined,
      },
      [
        el("div", { class: "row", style: "gap:12px;justify-content:flex-start" }, [
          el("span", { class: "list-icon", "aria-hidden": "true", text: icon }),
          el("div", { class: "stack" }, [
            el("div", { style: "font-weight:600", text: title }),
            el("div", { class: "tiny", text: subtitle }),
          ]),
        ]),
        enabled
          ? el("span", { class: "chev", text: "›" })
          : el("span", { class: "badge-soon", text: "Sắp có" }),
      ],
    );

  return el("div", { class: "screen" }, [
    el("div", { class: "app-title", text: "ShiftFlow" }),
    el("h1", { class: "screen-title", text: "Cài đặt" }),

    el("div", { class: "section-label", style: "margin-top:8px", text: "Cài đặt" }),
    el("div", { class: "list-group" }, [
      row("\u2699", "Cấu hình ca làm việc", "Quản lý các ca và quy tắc", () => go(ctx, "shifts")),
      row("\u2611", "Quản lý công việc", "Thêm, sửa, bật/tắt công việc", () => go(ctx, "tasks")),
      row("\uD83D\uDD14", "Nhắc nhở", "Thiết lập thời gian nhắc", undefined, false),
      row("\uD83C\uDFA8", "Giao diện", "Sáng / Tối / Tự động", undefined, false),
    ]),

    el("div", { class: "section-label", text: "Quản lý dữ liệu" }),
    el("div", { class: "list-group" }, [
      row("\uD83D\uDCBE", "Dữ liệu", "Sao lưu, khôi phục (JSON / CSV)", () => go(ctx, "data")),
    ]),

    el("div", { class: "section-label", text: "Thông tin" }),
    el("div", { class: "list-group" }, [
      row("\u2139", "Giới thiệu", "Phiên bản 0.1.0 · Local-first", () =>
        toast("ShiftFlow PWA 0.1.0 · Local-first"),
      ),
    ]),
  ]);
}

function backBar(ctx: ScreenContext, label: string, to: SettingsView): HTMLElement {
  return el("div", { class: "topbar" }, [
    el("button", { class: "btn ghost back", text: label, onClick: () => go(ctx, to) }),
  ]);
}

function pad(n: number): string {
  return String(n).padStart(2, "0");
}
function hhmm(h: number, m: number): string {
  return `${pad(h)}:${pad(m)}`;
}

// ---- Shift list (compact) ----

async function renderShiftList(ctx: ScreenContext): Promise<HTMLElement> {
  const shifts = (await app.configService.allShifts()).sort((a, b) =>
    a.code.localeCompare(b.code),
  );

  const rows = shifts.map((s) =>
    el(
      "div",
      {
        class: "list-row",
        role: "button",
        onClick: () => {
          editingShiftId = s.id;
          go(ctx, "shiftEditor");
        },
      },
      [
        el("div", { class: "row", style: "gap:12px;justify-content:flex-start" }, [
          el("span", {
            class: "swatch",
            "aria-hidden": "true",
            style: `background:${shiftDefinitionHex(s)}`,
          }),
          el("div", { class: "stack" }, [
            el("div", { style: "font-weight:700", text: s.code }),
            el("div", { class: "tiny", text: `Nghỉ ${hhmm(s.breakStartHour, s.breakStartMinute)}–${hhmm(s.breakEndHour, s.breakEndMinute)}` }),
          ]),
        ]),
        el("div", { class: "row", style: "gap:10px" }, [
          el("span", { style: "font-weight:600", text: `${hhmm(s.startHour, s.startMinute)}–${hhmm(s.endHour, s.endMinute)}` }),
          el("span", { class: "chev", text: "›" }),
        ]),
      ],
    ),
  );

  return el("div", { class: "screen" }, [
    backBar(ctx, "‹ Cài đặt", "root"),
    el("h1", { class: "screen-title", text: "Cấu hình ca" }),
    el("div", { class: "screen-subtitle", text: "Sửa giờ mặc định. Không ảnh hưởng WorkDay đã lưu." }),
    el("div", { class: "list-group" }, rows.length ? rows : [el("div", { class: "empty-state", text: "Chưa có ca." })]),
    el("button", {
      class: "btn primary block",
      text: "+ Thêm ca",
      onClick: () => {
        editingShiftId = null;
        go(ctx, "shiftEditor");
      },
    }),
  ]);
}

// ---- Shift editor (times + color; add or edit) ----

async function renderShiftEditor(ctx: ScreenContext): Promise<HTMLElement> {
  const shifts = await app.configService.allShifts();
  const existing = editingShiftId
    ? shifts.find((s) => s.id === editingShiftId)
    : undefined;

  let selectedColor: ShiftColor =
    existing?.color ?? "blue";

  // Single user-facing identity field ("Tên ca"). Internally this is the shift
  // code; existing shifts keep a stable code so the field is read-only on edit.
  const nameInput = el("input", {
    type: "text",
    value: existing?.code ?? "",
    placeholder: "Tên ca (vd: C6, Ca đêm)",
    ...(existing ? { disabled: "disabled" } : {}),
  });
  const start = el("input", { type: "time", value: existing ? hhmm(existing.startHour, existing.startMinute) : "08:00" });
  const end = el("input", { type: "time", value: existing ? hhmm(existing.endHour, existing.endMinute) : "17:00" });
  const bStart = el("input", { type: "time", value: existing ? hhmm(existing.breakStartHour, existing.breakStartMinute) : "12:00" });
  const bEnd = el("input", { type: "time", value: existing ? hhmm(existing.breakEndHour, existing.breakEndMinute) : "13:00" });

  const swatches = el(
    "div",
    { class: "swatch-row" },
    paletteEntries().map((p) =>
      el("button", {
        class: `swatch-btn${p.key === selectedColor ? " selected" : ""}`,
        "aria-label": p.key,
        "data-key": p.key,
        style: `background:${p.hex}`,
        onClick: (e: Event) => {
          selectedColor = p.key;
          const container = (e.target as HTMLElement).parentElement;
          container?.querySelectorAll(".swatch-btn").forEach((b) => b.classList.remove("selected"));
          (e.target as HTMLElement).classList.add("selected");
        },
      }),
    ),
  );

  const parse = (input: HTMLElement): [number, number] => {
    const [h, m] = (input as HTMLInputElement).value.split(":").map((x) => parseInt(x, 10));
    return [h || 0, m || 0];
  };

  const save = async () => {
    const [sh, sm] = parse(start);
    const [eh, em] = parse(end);
    const [bsh, bsm] = parse(bStart);
    const [beh, bem] = parse(bEnd);
    const nameValue = (nameInput as HTMLInputElement).value.trim();
    try {
      if (existing) {
        // Code (identity) is stable; only times/color change here.
        await app.configService.updateShift({
          ...existing,
          color: selectedColor,
          startHour: sh, startMinute: sm,
          endHour: eh, endMinute: em,
          breakStartHour: bsh, breakStartMinute: bsm,
          breakEndHour: beh, breakEndMinute: bem,
        });
        toast(`Đã lưu ${existing.code}`);
      } else {
        // The single "Tên ca" field becomes the code (and display name).
        const created = await app.configService.createShift({
          code: nameValue,
          name: nameValue || undefined,
          color: selectedColor,
          startHour: sh, startMinute: sm,
          endHour: eh, endMinute: em,
          breakStartHour: bsh, breakStartMinute: bsm,
          breakEndHour: beh, breakEndMinute: bem,
        });
        toast(`Đã thêm ${created.code}`);
      }
      go(ctx, "shifts");
    } catch (err) {
      toast(err instanceof Error ? err.message : "Lưu thất bại");
    }
  };

  const del = async () => {
    if (!existing) return;
    // Protection: never cascade-delete historical WorkDays.
    const usedBy = (await app.workDayService.all()).filter(
      (w) => w.shiftID === existing.id,
    ).length;
    if (usedBy > 0) {
      toast(`Không thể xóa ca — đang dùng trong ${usedBy} ngày làm việc.`);
      return;
    }
    await app.configService.deleteShift(existing.id);
    toast(`Đã xóa ca ${existing.code}`);
    go(ctx, "shifts");
  };

  return el("div", { class: "screen" }, [
    backBar(ctx, "‹ Cấu hình ca", "shifts"),
    el("h1", { class: "screen-title", text: existing ? existing.code : "Thêm ca" }),
    el("div", { class: "card" }, [
      field("Tên ca", nameInput),
      el("label", { class: "field" }, [el("span", { text: "Màu ca" }), swatches]),
      field("Bắt đầu", start),
      field("Kết thúc", end),
      field("Nghỉ từ", bStart),
      field("Nghỉ đến", bEnd),
    ]),
    el("div", { class: "btn-row" }, [
      el("button", { class: "btn ghost block", text: "Hủy", onClick: () => go(ctx, "shifts") }),
      el("button", { class: "btn primary block", text: "Lưu", onClick: () => void save() }),
    ]),
    existing
      ? el("button", {
          class: "btn danger block",
          style: "margin-top:8px",
          text: "Xóa ca",
          onClick: () => void del(),
        })
      : null,
  ]);
}

function field(label: string, input: HTMLElement): HTMLElement {
  return el("label", { class: "field" }, [el("span", { text: label }), input]);
}

// ---- Task list (compact) ----

async function renderTaskList(ctx: ScreenContext): Promise<HTMLElement> {
  const tasks = await app.taskService.allTasks();

  const rows = tasks.length
    ? tasks.map((t) =>
        el("div", { class: "list-row" }, [
          el("div", { class: "stack" }, [
            el("div", { style: "font-weight:600", text: `${t.code} — ${t.name}` }),
            el("div", { class: "tiny", text: t.isActive ? "Đang bật" : "Đã tắt" }),
          ]),
          el("button", {
            class: `btn ghost small ${t.isActive ? "" : "muted-btn"}`,
            text: t.isActive ? "Bật" : "Tắt",
            onClick: async (e: Event) => {
              (e as Event).stopPropagation();
              await app.taskService.setActive(t.id, !t.isActive);
              ctx.refresh();
            },
          }),
        ]),
      )
    : [el("div", { class: "empty-state", text: "Chưa có công việc." })];

  return el("div", { class: "screen" }, [
    backBar(ctx, "‹ Cài đặt", "root"),
    el("h1", { class: "screen-title", text: "Quản lý công việc" }),
    el("div", { class: "list-group" }, rows),
    el("button", {
      class: "btn primary block",
      text: "+ Thêm công việc",
      onClick: () => {
        editingTaskId = null;
        go(ctx, "taskEditor");
      },
    }),
  ]);
}

async function renderTaskEditor(ctx: ScreenContext): Promise<HTMLElement> {
  void editingTaskId; // only "add" is supported here in M1
  const codeInput = el("input", { type: "text", placeholder: "Mã (vd: Ticket)" });
  const nameInput = el("input", { type: "text", placeholder: "Tên hiển thị" });

  const add = async () => {
    try {
      await app.taskService.createTask(
        (codeInput as HTMLInputElement).value,
        (nameInput as HTMLInputElement).value,
      );
      toast("Đã thêm công việc");
      go(ctx, "tasks");
    } catch (err) {
      toast(err instanceof Error ? err.message : "Thêm thất bại");
    }
  };

  return el("div", { class: "screen" }, [
    backBar(ctx, "‹ Quản lý công việc", "tasks"),
    el("h1", { class: "screen-title", text: "Thêm công việc" }),
    el("div", { class: "card" }, [field("Mã", codeInput), field("Tên", nameInput)]),
    el("div", { class: "btn-row" }, [
      el("button", { class: "btn ghost block", text: "Hủy", onClick: () => go(ctx, "tasks") }),
      el("button", { class: "btn primary block", text: "Lưu", onClick: () => void add() }),
    ]),
  ]);
}
