// ShiftFlow PWA — UI
// ui/screens/dayDetailSheet.ts
//
// Day Detail bottom sheet with VIEW (default) and EDIT modes.
//
// - VIEW: read-only. Shows shift, times, VISIBLE tasks, note, reminder. A
//   pencil (✏) in the header switches to EDIT.
// - EDIT: change shift, add/remove task, hide/unhide task (eye — never deletes
//   the definition), edit note, set reminder, Save/Delete.
//
// Single source of truth: task visibility is read/written on WorkDayTask
// (isVisible). No per-screen visibility state.

import { app } from "@/services/appContainer";
import { el, toast } from "@/ui/components/dom";
import { buildShiftColorMap, colorForCode, longDate, shiftBadge, timeFromISO } from "@/ui/components/format";
import { fromISODateLocal } from "@/domain/resolver/datetime";
import type { ReminderOffset, TaskDefinition, WorkDay } from "@/domain/models/models";
import { ALL_REMINDER_OFFSETS, offsetLabel } from "@/domain/resolver/reminderTiming";
import { resolveShift } from "@/domain/resolver/shiftResolver";

export interface DayDetailOptions {
  /** Initial mode. Defaults to "view" (single click/tap opens view). */
  mode?: "view" | "edit";
}

export async function openDayDetail(
  isoDate: string,
  onChange: () => void,
  opts: DayDetailOptions = {},
): Promise<void> {
  const date = fromISODateLocal(isoDate);
  const existing = await app.workDayService.byDate(date);
  const shifts = await app.configService.activeShifts();
  const allRules = await app.configService.allRules();
  let allTasks = await app.taskService.activeTasks();
  const colors = buildShiftColorMap(shifts);

  // Synchronous shift lookup from the config loaded when the sheet opened.
  // Using this (instead of an async configService.lookup) at save time keeps
  // the entire save on a SINGLE transaction boundary, so onChange() fires
  // deterministically right after persistence (mirrors the delete path).
  function resolveLookup(
    code: string,
  ): { shift: (typeof shifts)[number]; rules: typeof allRules } | null {
    const normalized = code.trim().toUpperCase();
    const shift = shifts.find((s) => s.code.toUpperCase() === normalized);
    if (!shift) return null;
    return { shift, rules: allRules.filter((r) => r.shiftID === shift.id) };
  }

  let mode: "view" | "edit" = opts.mode ?? "view";

  // Local editable state.
  let selectedCode: string = existing?.shiftCode ?? "OFF";
  let workDay: WorkDay | undefined = existing;

  // Task assignment state: taskId -> { assigned, visible }. Loaded from the
  // single source of truth (WorkDayTask incl. isVisible).
  const taskState = new Map<string, {
    assigned: boolean;
    visible: boolean;
    startTime: string;
    endTime: string;
    reminderEnabled: boolean;
    reminderOffset: ReminderOffset;
  }>();
  if (existing) {
    for (const a of await app.taskService.assignmentsForWorkDay(existing.id)) {
      taskState.set(a.task.id, {
        assigned: true,
        visible: a.isVisible,
        startTime: a.assignment.startTime ?? "",
        endTime: a.assignment.endTime ?? "",
        reminderEnabled: a.assignment.reminderEnabled ?? false,
        reminderOffset: a.assignment.reminderOffset ?? "30min",
      });
    }
  }
  for (const t of allTasks) {
    if (!taskState.has(t.id)) {
      taskState.set(t.id, {
        assigned: false,
        visible: true,
        startTime: "",
        endTime: "",
        reminderEnabled: false,
        reminderOffset: "30min",
      });
    }
  }

  let note = existing?.note ?? "";
  const reminder = existing ? await app.reminderService.forWorkDay(existing.id) : undefined;
  let reminderEnabled = reminder?.isEnabled ?? false;
  let reminderOffset: ReminderOffset = reminder?.offset ?? "2h";
  let isAddingTask = false;

  const backdrop = el("div", { class: "sheet-backdrop", role: "dialog", "aria-modal": "true" });
  const sheet = el("div", { class: "sheet" });
  backdrop.append(sheet);
  const close = () => backdrop.remove();
  backdrop.addEventListener("click", (e) => {
    if (e.target === backdrop) close();
  });

  function resolvedPreview(): {
    startDateTime: string;
    endDateTime: string;
    breakStartDateTime: string;
    breakEndDateTime: string;
  } | null {
    if (selectedCode === "OFF") return null;
    if (workDay && workDay.shiftCode === selectedCode) {
      return {
        startDateTime: workDay.resolvedStartDateTime,
        endDateTime: workDay.resolvedEndDateTime,
        breakStartDateTime: workDay.resolvedBreakStartDateTime,
        breakEndDateTime: workDay.resolvedBreakEndDateTime,
      };
    }
    return null; // computed asynchronously in edit-mode preview
  }

  // ---------- SAVE / DELETE ----------

  // Tables touched by any save/delete write path. taskDefinitions is READ by
  // TaskService.tasksForWorkDay() (it joins assignments -> definitions); it must
  // be in the transaction scope or Dexie aborts the transaction ("table not
  // part of transaction"), which previously swallowed the save and skipped the
  // refresh callback. Delete never reads taskDefinitions, which is why it passed.
  const writeTables = [
    app.db.workDays,
    app.db.workDayTasks,
    app.db.reminders,
    app.db.taskDefinitions,
  ];

  async function save(): Promise<void> {
    try {
      // OFF = no WorkDay: delete the existing one (single transaction) if any.
      if (selectedCode === "OFF") {
        if (workDay) {
          const id = workDay.id;
          await app.db.transaction("rw", writeTables, async () => {
            await app.taskService.removeAllTasks(id);
            await app.reminderService.clearReminder(id);
            await app.workDayService.delete(id);
          });
        }
        toast("Đã đặt OFF");
        onChange();
        close();
        return;
      }

      // Resolve shift config from data loaded at sheet-open (synchronous — no
      // IndexedDB read here), so the whole save is a single transaction.
      const lookup = resolveLookup(selectedCode);
      if (!lookup) {
        toast("Không tìm thấy cấu hình ca");
        return;
      }

      // All writes run inside ONE transaction so the operation settles as a
      // single unit before onChange() fires (fixes the refresh-not-fired race).
      await app.db.transaction("rw", writeTables, async () => {
        let wd: WorkDay;
        if (!workDay) {
          wd = await app.workDayService.create(date, lookup.shift, lookup.rules, note);
        } else {
          wd = workDay;
          if (wd.shiftCode !== selectedCode) {
            wd = await app.workDayService.changeShift(wd.id, lookup.shift, lookup.rules);
          }
          await app.workDayService.updateNote(wd.id, note);
        }
        workDay = wd;

        const current = new Set(
          (await app.taskService.tasksForWorkDay(wd.id)).map((t) => t.id),
        );
        for (const [id, st] of taskState) {
          if (st.assigned && !current.has(id)) await app.taskService.addTask(id, wd.id);
          if (!st.assigned && current.has(id)) await app.taskService.removeTask(id, wd.id);
          if (st.assigned) {
            await app.taskService.setTaskVisibility(id, wd.id, st.visible);
            await app.taskService.setTaskDetails(id, wd.id, {
              startTime: st.startTime || null,
              endTime: st.endTime || null,
              reminderEnabled: st.reminderEnabled,
              reminderOffset: st.reminderEnabled ? st.reminderOffset : null,
            });
          }
        }

        if (reminderEnabled) {
          await app.reminderService.setReminder(wd.id, reminderOffset, true);
        } else {
          await app.reminderService.clearReminder(wd.id);
        }
      });

      await app.notificationScheduler.reschedule();
      toast("Đã lưu");
      onChange();
      close();
    } catch (err) {
      toast(err instanceof Error ? err.message : "Lưu thất bại");
    }
  }

  /**
   * Performs the actual deletion, then closes and refreshes the views.
   *
   * All three writes run inside ONE Dexie transaction so the operation settles
   * as a single unit before onChange() fires — the refresh is guaranteed to be
   * observed after persistence completes (fixes the "refresh not fired / record
   * still present" race where the awaited work spanned multiple commits).
   */
  async function performDelete(): Promise<void> {
    if (!workDay) {
      close();
      return;
    }
    const id = workDay.id;
    await app.db.transaction("rw", writeTables, async () => {
      await app.taskService.removeAllTasks(id);
      await app.reminderService.clearReminder(id);
      await app.workDayService.delete(id);
    });
    toast("Đã xóa");
    onChange(); // refresh Calendar / Overview / 3 Days
    close();
  }

  /**
   * Opens a confirmation dialog before deleting. Nothing is deleted until the
   * user confirms; "Hủy" closes the dialog and keeps the Edit screen open.
   */
  function requestDelete(): void {
    if (!workDay) {
      close();
      return;
    }
    const confirm = el("div", { class: "confirm-backdrop", role: "dialog", "aria-modal": "true" });
    const closeConfirm = () => confirm.remove();
    confirm.addEventListener("click", (e) => {
      if (e.target === confirm) closeConfirm();
    });

    confirm.append(
      el("div", { class: "confirm-dialog" }, [
        el("div", { class: "confirm-title", text: "Xóa ngày này?" }),
        el("div", {
          class: "confirm-message",
          text: `Bạn có chắc muốn xóa lịch làm việc ngày ${longDate(date)}?`,
        }),
        el("div", { class: "btn-row", style: "margin-top:18px" }, [
          el("button", {
            class: "btn ghost block",
            text: "Hủy",
            onClick: closeConfirm,
          }),
          el("button", {
            class: "btn danger block",
            text: "Xóa",
            onClick: () => {
              closeConfirm();
              void performDelete();
            },
          }),
        ]),
      ]),
    );

    document.body.append(confirm);
  }

  // ---------- HEADER ----------

  function header(): HTMLElement {
    const closeBtn = el("button", {
      class: "icon-action ghost",
      "aria-label": "Đóng",
      title: "Đóng",
      text: "\u2715", // ✕
      onClick: close,
    });

    // VIEW header has a pencil (the only edit entry point). EDIT header has NO
    // save action — saving is done via the single bottom "Lưu" button, so there
    // is exactly one obvious Save. A spacer keeps the title centered.
    const rightSlot =
      mode === "view"
        ? el("button", {
            class: "icon-action",
            "aria-label": "Sửa",
            title: "Sửa",
            text: "\u270F\uFE0F", // ✏️
            onClick: () => {
              mode = "edit";
              void render();
            },
          })
        : el("span", { class: "icon-action-spacer", "aria-hidden": "true" });

    return el("div", {}, [
      el("div", { class: "row", style: "align-items:center" }, [
        closeBtn,
        el("div", { class: "sheet-heading", text: mode === "view" ? "Chi tiết ngày" : "Chỉnh sửa ngày" }),
        rightSlot,
      ]),
      el("div", { class: "sheet-date", text: longDate(date) }),
    ]);
  }

  // ---------- VIEW MODE ----------

  async function renderView(): Promise<HTMLElement[]> {
    const parts: HTMLElement[] = [header()];

    if (!workDay) {
      parts.push(
        el("div", { class: "card", style: "margin-top:8px" }, [
          el("div", { class: "row", style: "align-items:center" }, [
            shiftBadge("OFF", colors, { size: "md" }),
            el("div", { class: "stack", style: "flex:1;margin-left:12px" }, [
              el("div", { class: "time", style: "font-size:18px", text: "Nghỉ" }),
              el("div", { class: "muted", text: "Không có ca làm" }),
            ]),
          ]),
        ]),
      );
      // No bottom "Sửa": the header pencil is the only edit entry point.
      return parts;
    }

    const w = workDay;
    const visibleTasks = (await app.taskService.assignmentsForWorkDay(w.id))
      .filter((a) => a.isVisible);

    parts.push(
      el("div", { class: "card", style: "margin-top:8px" }, [
        el("div", { class: "row", style: "align-items:center" }, [
          shiftBadge(w.shiftCode, colors, { size: "md" }),
          el("div", { class: "stack", style: "flex:1;margin-left:12px" }, [
            el("div", { class: "time", style: "font-size:18px", text: `${timeFromISO(w.resolvedStartDateTime)} – ${timeFromISO(w.resolvedEndDateTime)}` }),
            el("div", { class: "muted", text: `Nghỉ ${timeFromISO(w.resolvedBreakStartDateTime)}–${timeFromISO(w.resolvedBreakEndDateTime)}` }),
          ]),
        ]),
      ]),
    );

    parts.push(el("div", { class: "section-label", text: "Công việc" }));
    parts.push(
      visibleTasks.length
        ? el("div", { class: "task-list" }, visibleTasks.map(({ task, assignment }) =>
            el("div", { class: "task-row" }, [
              el("div", { class: "stack", style: "flex:1" }, [
                el("div", { style: "font-weight:600", text: task.code }),
                el("div", {
                  class: "tiny",
                  text: assignment.startTime && assignment.endTime
                    ? `${assignment.startTime}–${assignment.endTime}`
                    : task.name,
                }),
              ]),
              assignment.reminderEnabled
                ? el("span", { class: "badge-soon", text: offsetLabel(assignment.reminderOffset ?? "30min") })
                : null,
            ]),
          ))
        : el("div", { class: "muted", text: "Không có task" }),
    );

    parts.push(el("div", { class: "section-label", text: "Ghi chú" }));
    parts.push(el("div", { class: w.note ? "" : "muted", text: w.note ? w.note : "Không có ghi chú" }));

    parts.push(el("div", { class: "section-label", text: "Nhắc nhở" }));
    parts.push(
      el("div", { class: reminderEnabled ? "" : "muted", text: reminderEnabled ? offsetLabel(reminderOffset) : "Tắt" }),
    );

    // No bottom "Sửa": the header pencil (✏️) is the only edit entry point.
    return parts;
  }

  // ---------- EDIT MODE ----------

  function editShiftChips(): HTMLElement {
    const chip = (code: string, isOff = false): HTMLElement =>
      el(
        "button",
        {
          class: `chip ${selectedCode === code ? "selected" : ""}`,
          "data-code": code,
          onClick: () => {
            selectedCode = code;
            render();
          },
        },
        [
          el("span", {
            class: "chip-dot",
            "aria-hidden": "true",
            style: `background:${isOff ? "var(--shift-off)" : colorForCode(code, colors)}`,
          }),
          code,
        ],
      );
    return el("div", { class: "chips" }, [chip("OFF", true), ...shifts.map((s) => chip(s.code))]);
  }

  async function editTimesBlock(): Promise<HTMLElement> {
    if (selectedCode === "OFF") {
      return el("div", { class: "card tight", style: "margin-top:12px" }, [
        el("div", { class: "muted", text: "Ngày nghỉ (OFF) — không có lịch làm việc." }),
      ]);
    }
    let resolved = resolvedPreview();
    if (!resolved) {
      const lookup = resolveLookup(selectedCode);
      if (lookup) {
        const r = resolveShift(date, lookup.shift, lookup.rules);
        resolved = {
          startDateTime: r.startDateTime,
          endDateTime: r.endDateTime,
          breakStartDateTime: r.breakStartDateTime,
          breakEndDateTime: r.breakEndDateTime,
        };
      }
    }
    return el("div", { class: "card tight", style: "margin-top:12px" }, [
      resolved
        ? el("div", { class: "time-grid" }, [
            timeCol("Bắt đầu", timeFromISO(resolved.startDateTime)),
            timeCol("Nghỉ", `${timeFromISO(resolved.breakStartDateTime)}–${timeFromISO(resolved.breakEndDateTime)}`),
            timeCol("Kết thúc", timeFromISO(resolved.endDateTime)),
          ])
        : el("div", { class: "muted", text: "" }),
    ]);
  }

  function editTaskSection(): HTMLElement {
    const assigned = allTasks.filter((t) => taskState.get(t.id)?.assigned);
    const unassigned = allTasks.filter((t) => !taskState.get(t.id)?.assigned);

    const list = el(
      "div",
      { class: "task-list" },
      assigned.length
        ? assigned.map((t) => assignedTaskRow(t))
        : [el("div", { class: "tiny", text: "Chưa gán task nào." })],
    );

    const add = el(
      "div",
      { class: "chips", style: "margin-top:10px" },
      unassigned.length
        ? [
            el("span", { class: "tiny", style: "align-self:center;margin-right:4px", text: "Thêm:" }),
            ...unassigned.map((t) =>
              el("button", {
                class: "chip",
                text: `+ ${t.code}`,
                onClick: () => {
                  const st = taskState.get(t.id)!;
                  st.assigned = true;
                  st.visible = true;
                  render();
                },
              }),
            ),
          ]
        : [],
    );

    const addNew = isAddingTask ? newTaskForm() : el("button", {
      class: "btn ghost block",
      style: "margin-top:10px",
      text: "+ Công việc",
      onClick: () => {
        isAddingTask = true;
        void render();
      },
    });

    return el("div", {}, [list, add, addNew]);
  }

  function newTaskForm(): HTMLElement {
    const codeInput = el("input", {
      type: "text",
      placeholder: "Mã (vd: Meeting)",
    });
    const nameInput = el("input", {
      type: "text",
      placeholder: "Tên hiển thị",
    });

    const create = async () => {
      try {
        const code = (codeInput as HTMLInputElement).value.trim();
        const name = (nameInput as HTMLInputElement).value.trim() || code;
        const created = await app.taskService.createTask(code, name);
        allTasks = await app.taskService.activeTasks();
        taskState.set(created.id, {
          assigned: true,
          visible: true,
          startTime: "",
          endTime: "",
          reminderEnabled: false,
          reminderOffset: "30min",
        });
        isAddingTask = false;
        toast(`Đã thêm ${created.code}`);
        void render();
      } catch (err) {
        toast(err instanceof Error ? err.message : "Thêm công việc thất bại");
      }
    };

    return el("div", { class: "card tight inline-task-form", style: "margin-top:10px" }, [
      field("Mã công việc", codeInput),
      field("Tên", nameInput),
      el("div", { class: "btn-row" }, [
        el("button", {
          class: "btn ghost block",
          text: "Hủy",
          onClick: () => {
            isAddingTask = false;
            void render();
          },
        }),
        el("button", {
          class: "btn primary block",
          text: "Thêm",
          onClick: () => void create(),
        }),
      ]),
    ]);
  }

  function assignedTaskRow(t: TaskDefinition): HTMLElement {
    const st = taskState.get(t.id)!;
    const eye = el("button", {
      class: `eye-btn ${st.visible ? "on" : "off"}`,
      "aria-label": st.visible ? `Ẩn ${t.code}` : `Hiện ${t.code}`,
      title: st.visible ? "Đang hiển thị — bấm để ẩn" : "Đang ẩn — bấm để hiện",
      text: st.visible ? "\uD83D\uDC41" : "\uD83D\uDEAB", // 👁 / 🚫
      onClick: () => {
        st.visible = !st.visible;
        render();
      },
    });
    const remove = el("button", {
      class: "btn ghost small",
      "aria-label": `Bỏ ${t.code}`,
      text: "×",
      onClick: () => {
        st.assigned = false;
        render();
      },
    });
    return el("div", { class: `task-row ${st.visible ? "" : "hidden-task"}` }, [
      eye,
      el("div", { class: "stack", style: "flex:1;gap:8px" }, [
        el("div", { style: "font-weight:600", text: t.code }),
        el("div", { class: "tiny", text: st.visible ? t.name : "Đang ẩn" }),
        el("div", { class: "task-time-grid" }, [
          el("label", { class: "field compact" }, [
            el("span", { text: "Bắt đầu" }),
            el("input", {
              type: "time",
              value: st.startTime,
              onInput: (e: Event) => {
                st.startTime = (e.target as HTMLInputElement).value;
              },
            }),
          ]),
          el("label", { class: "field compact" }, [
            el("span", { text: "Kết thúc" }),
            el("input", {
              type: "time",
              value: st.endTime,
              onInput: (e: Event) => {
                st.endTime = (e.target as HTMLInputElement).value;
              },
            }),
          ]),
        ]),
        el("div", { class: "task-reminder-row" }, [
          el("label", { class: "row task-reminder-toggle" }, [
            el("span", { class: "tiny", text: "Nhắc việc" }),
            el("input", {
              type: "checkbox",
              ...(st.reminderEnabled ? { checked: "checked" } : {}),
              onChange: (e: Event) => {
                st.reminderEnabled = (e.target as HTMLInputElement).checked;
                if (st.reminderEnabled) void app.notificationScheduler.requestPermission();
              },
            }),
          ]),
          el(
            "select",
            {
              onChange: (e: Event) => {
                st.reminderOffset = (e.target as HTMLSelectElement).value as ReminderOffset;
              },
            },
            ALL_REMINDER_OFFSETS.map((o) =>
              el("option", { value: o, ...(o === st.reminderOffset ? { selected: "selected" } : {}) }, [offsetLabel(o)]),
            ),
          ),
        ]),
      ]),
      remove,
    ]);
  }

  async function renderEdit(): Promise<HTMLElement[]> {
    const noteInput = el("textarea", {
      placeholder: "Ghi chú cho ngày này…",
      text: note,
      onInput: (e: Event) => {
        note = (e.target as HTMLTextAreaElement).value;
      },
    });

    const reminderToggle = el("input", {
      type: "checkbox",
      ...(reminderEnabled ? { checked: "checked" } : {}),
      onChange: (e: Event) => {
        reminderEnabled = (e.target as HTMLInputElement).checked;
      },
    });
    const reminderSelect = el(
      "select",
      {
        onChange: (e: Event) => {
          reminderOffset = (e.target as HTMLSelectElement).value as ReminderOffset;
        },
      },
      ALL_REMINDER_OFFSETS.map((o) =>
        el("option", { value: o, ...(o === reminderOffset ? { selected: "selected" } : {}) }, [offsetLabel(o)]),
      ),
    );

    return [
      header(),
      el("div", { class: "section-label", text: "Ca làm việc" }),
      editShiftChips(),
      await editTimesBlock(),
      el("div", { class: "section-label", text: "Task" }),
      editTaskSection(),
      el("div", { class: "section-label", text: "Ghi chú" }),
      noteInput,
      el("div", { class: "section-label", text: "Nhắc nhở" }),
      el("div", { class: "card tight" }, [
        el("label", { class: "row", style: "cursor:pointer" }, [
          el("span", { text: "Bật nhắc nhở" }),
          reminderToggle,
        ]),
        el("div", { class: "divider" }),
        reminderSelect,
        el("div", {
          class: "tiny",
          style: "margin-top:8px",
          text: "Nhắc nhở tính từ giờ bắt đầu ca. Gửi thông báo nền chưa có ở bản M1.",
        }),
      ]),
      el("div", { class: "btn-row", style: "margin-top:20px" }, [
        el("button", { class: "btn primary block", text: "Lưu", onClick: () => void save() }),
        workDay ? el("button", { class: "btn danger", text: "Xóa", onClick: () => requestDelete() }) : el("span"),
      ]),
    ];
  }

  // ---------- RENDER ----------

  async function render(): Promise<void> {
    const children = mode === "view" ? await renderView() : await renderEdit();
    sheet.replaceChildren(el("div", { class: "sheet-handle" }), ...children);
  }

  document.body.append(backdrop);
  await render();
}

function timeCol(label: string, value: string): HTMLElement {
  return el("div", {}, [
    el("div", { class: "time-label", text: label }),
    el("div", { class: "time", text: value }),
  ]);
}

function field(label: string, input: HTMLElement): HTMLElement {
  return el("label", { class: "field" }, [el("span", { text: label }), input]);
}
