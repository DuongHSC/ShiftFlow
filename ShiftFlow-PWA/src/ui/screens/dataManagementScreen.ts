// ShiftFlow PWA — UI
// ui/screens/dataManagementScreen.ts
//
// Dedicated Data Management screen.
//   Export Data:  Export JSON (complete backup) / Export CSV (calendar exchange)
//   Load Data:    Import JSON / Import CSV  ->  choose file -> validate ->
//                 preview -> import (Replace / Merge for JSON; strategy for CSV)
//
// Normal app startup never requires Load Data — this is an explicit action.

import { app } from "@/services/appContainer";
import { db } from "@/storage/db/db";
import { el, toast } from "@/ui/components/dom";
import { toISODateLocal } from "@/domain/resolver/datetime";
import {
  applyBackup,
  exportBackupJson,
  parseBackup,
  type BackupImportMode,
  type ShiftFlowBackup,
} from "@/import-export/json/jsonBackup";
import {
  CsvParseError,
} from "@/import-export/csv/csv";
import type { ImportConflictStrategy, ImportPreview } from "@/import-export/csv/csvService";
import { loadDemoData } from "@/storage/demoData";

export interface DataScreenContext {
  back: () => void;
  refresh: () => void;
}

/**
 * Dev-only "Load demo data" card. Rendered ONLY in development builds
 * (import.meta.env.DEV); returns an empty text node in production so no demo
 * affordance ships to users. Never auto-runs — the user must click.
 */
function demoDataCard(ctx: DataScreenContext): Node {
  if (!import.meta.env.DEV) return document.createTextNode("");
  return el("div", {}, [
    el("div", { class: "section-label", text: "Chỉ dành cho phát triển" }),
    el("div", { class: "card" }, [
      el("div", { class: "muted", style: "margin-bottom:12px", text: "Nạp ~13 ngày dữ liệu mẫu để review giao diện. Không dùng trong bản phát hành." }),
      el("button", {
        class: "btn block",
        text: "Nạp dữ liệu mẫu (demo)",
        onClick: async () => {
          const ok = window.confirm(
            "Nạp ~13 ngày dữ liệu mẫu? Các ngày bạn đã có dữ liệu sẽ được GIỮ NGUYÊN (không ghi đè).",
          );
          if (!ok) return;
          try {
            const r = await loadDemoData(app);
            toast(`Đã nạp ${r.created} ngày mẫu · giữ nguyên ${r.skipped}`);
            ctx.refresh();
          } catch (err) {
            toast(err instanceof Error ? err.message : "Nạp demo thất bại");
          }
        },
      }),
    ]),
  ]);
}

function fileStamp(): string {
  return toISODateLocal(new Date());
}

function downloadText(filename: string, text: string, mime: string): void {
  const blob = new Blob([text], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = el("a", { href: url, download: filename });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

async function pickFile(accept: string): Promise<File | null> {
  return new Promise((resolve) => {
    const input = el("input", { type: "file", accept, style: "display:none" });
    input.addEventListener("change", () => {
      resolve(input.files && input.files[0] ? input.files[0] : null);
      input.remove();
    });
    document.body.append(input);
    input.click();
  });
}

export function renderDataManagement(ctx: DataScreenContext): HTMLElement {
  const screen = el("div", { class: "screen" }, [
    el("div", { class: "row", style: "margin-bottom:8px" }, [
      el("button", { class: "btn ghost", text: "‹ Cài đặt", onClick: ctx.back }),
    ]),
    el("h1", { class: "screen-title", text: "Dữ liệu" }),
    el("div", { class: "screen-subtitle", text: "Sao lưu và khôi phục thủ công. Dữ liệu luôn ở trên thiết bị." }),

    el("div", { class: "section-label", style: "margin-top:0", text: "Xuất dữ liệu" }),
    el("div", { class: "card" }, [
      el("div", { class: "data-line" }, [
        el("div", { class: "stack" }, [
          el("div", { style: "font-weight:600", text: "Xuất JSON" }),
          el("div", { class: "tiny", text: "Backup toàn bộ dữ liệu local." }),
        ]),
        el("button", { class: "btn primary small", text: "Xuất JSON", onClick: () => void exportJson() }),
      ]),
      el("div", { class: "divider" }),
      el("div", { class: "data-line" }, [
        el("div", { class: "stack" }, [
          el("div", { style: "font-weight:600", text: "Xuất CSV" }),
          el("div", { class: "tiny", text: "Dùng để xem/chuyển lịch làm việc." }),
        ]),
        el("button", { class: "btn small", text: "Xuất CSV", onClick: () => void exportCsv() }),
      ]),
    ]),

    el("div", { class: "section-label", text: "Nạp dữ liệu" }),
    el("div", { class: "card" }, [
      el("div", { class: "data-line" }, [
        el("div", { class: "stack" }, [
          el("div", { style: "font-weight:600", text: "Nhập JSON" }),
          el("div", { class: "tiny", text: "Khôi phục dữ liệu." }),
        ]),
        el("button", { class: "btn primary small", text: "Nhập JSON", onClick: () => void loadJson() }),
      ]),
      el("div", { class: "divider" }),
      el("div", { class: "data-line" }, [
        el("div", { class: "stack" }, [
          el("div", { style: "font-weight:600", text: "Nhập CSV" }),
          el("div", { class: "tiny", text: "Nhập lịch làm việc." }),
        ]),
        el("button", { class: "btn small", text: "Nhập CSV", onClick: () => void loadCsv() }),
      ]),
      el("div", { class: "divider" }),
      el("div", { class: "tiny", text: "Chọn tệp → xem trước → nhập. Không ghi đè âm thầm." }),
    ]),

    demoDataCard(ctx),
  ]);

  async function exportJson(): Promise<void> {
    try {
      const json = await exportBackupJson(db);
      downloadText(`ShiftFlow-${fileStamp()}.json`, json, "application/json");
      toast("Đã xuất JSON");
    } catch {
      toast("Xuất JSON thất bại");
    }
  }

  async function exportCsv(): Promise<void> {
    try {
      const csv = await app.csvService.exportCsv();
      downloadText(`ShiftFlow-${fileStamp()}.csv`, csv, "text/csv");
      toast("Đã xuất CSV");
    } catch {
      toast("Xuất CSV thất bại");
    }
  }

  async function loadJson(): Promise<void> {
    const file = await pickFile(".json,application/json");
    if (!file) return;
    let backup: ShiftFlowBackup;
    try {
      backup = parseBackup(await file.text());
    } catch (err) {
      toast(err instanceof Error ? err.message : "File JSON không hợp lệ");
      return;
    }
    openJsonPreview(backup, ctx);
  }

  async function loadCsv(): Promise<void> {
    const file = await pickFile(".csv,text/csv,text/plain");
    if (!file) return;
    let preview: ImportPreview;
    try {
      preview = await app.csvService.prepareImport(await file.text());
    } catch (err) {
      if (err instanceof CsvParseError) {
        toast(err.message);
      } else {
        toast("Không đọc được CSV");
      }
      return;
    }
    openCsvPreview(preview, ctx);
  }

  return screen;
}

// ---- JSON preview / import sheet ----

function openJsonPreview(backup: ShiftFlowBackup, ctx: DataScreenContext): void {
  const d = backup.data;
  let mode: BackupImportMode = "merge";

  const backdrop = el("div", { class: "sheet-backdrop", role: "dialog", "aria-modal": "true" });
  const sheet = el("div", { class: "sheet" });
  backdrop.append(sheet);
  const close = () => backdrop.remove();
  backdrop.addEventListener("click", (e) => e.target === backdrop && close());

  const modeChip = (m: BackupImportMode, label: string) =>
    el("button", {
      class: `chip ${mode === m ? "selected" : ""}`,
      text: label,
      onClick: (e: Event) => {
        mode = m;
        sheet.querySelectorAll(".mode-chips .chip").forEach((c) =>
          c.classList.remove("selected"),
        );
        (e.target as HTMLElement).classList.add("selected");
      },
    });

  sheet.append(
    el("div", { class: "sheet-handle" }),
    el("h2", { style: "margin-top:0", text: "Xem trước bản sao lưu" }),
    el("div", { class: "muted", text: `Xuất lúc: ${new Date(backup.exportedAt).toLocaleString()}` }),
    el("div", { class: "card tight", style: "margin-top:12px" }, [
      summaryRow("WorkDays", d.workDays.length),
      summaryRow("Cấu hình ca", d.shiftDefinitions.length),
      summaryRow("Quy tắc lịch", d.scheduleRules.length),
      summaryRow("Task", d.taskDefinitions.length),
      summaryRow("Gán task", d.workDayTasks.length),
      summaryRow("Nhắc nhở", d.reminders.length),
    ]),
    el("div", { class: "section-label", text: "Chế độ nhập" }),
    el("div", { class: "chips mode-chips" }, [
      modeChip("merge", "Gộp (Merge)"),
      modeChip("replace", "Thay thế (Replace)"),
    ]),
    el("div", { class: "tiny", style: "margin-top:8px", text: "Gộp: cập nhật theo id. Thay thế: xóa toàn bộ rồi nạp lại." }),
    el("div", { class: "btn-row", style: "margin-top:20px" }, [
      el("button", {
        class: "btn primary block",
        text: "Nhập",
        onClick: async () => {
          try {
            const s = await applyBackup(db, backup, mode);
            toast(`Đã nhập ${s.workDays} WorkDays (${mode})`);
            close();
            ctx.refresh();
          } catch (err) {
            toast(err instanceof Error ? err.message : "Nhập thất bại");
          }
        },
      }),
      el("button", { class: "btn ghost", text: "Hủy", onClick: close }),
    ]),
  );

  document.body.append(backdrop);
}

// ---- CSV preview / import sheet ----

function openCsvPreview(preview: ImportPreview, ctx: DataScreenContext): void {
  let strategy: ImportConflictStrategy = "skipExisting";

  const backdrop = el("div", { class: "sheet-backdrop", role: "dialog", "aria-modal": "true" });
  const sheet = el("div", { class: "sheet" });
  backdrop.append(sheet);
  const close = () => backdrop.remove();
  backdrop.addEventListener("click", (e) => e.target === backdrop && close());

  const stratChip = (s: ImportConflictStrategy, label: string) =>
    el("button", {
      class: `chip ${strategy === s ? "selected" : ""}`,
      text: label,
      onClick: (e: Event) => {
        strategy = s;
        sheet.querySelectorAll(".strat-chips .chip").forEach((c) =>
          c.classList.remove("selected"),
        );
        (e.target as HTMLElement).classList.add("selected");
      },
    });

  // Build the sheet children, adding conditional blocks only when relevant so
  // no null is ever passed to Element.append (which accepts only string | Node).
  const sheetChildren: (string | Node)[] = [
    el("div", { class: "sheet-handle" }),
    el("h2", { style: "margin-top:0", text: "Xem trước nhập CSV" }),
    el("div", { class: "card tight", style: "margin-top:12px" }, [
      summaryRow("Tổng dòng", preview.total),
      summaryRow("Hợp lệ", preview.validCount),
      summaryRow("OFF", preview.offCount),
      summaryRow("Trùng trong file", preview.duplicateCount),
      summaryRow("Xung đột (đã tồn tại)", preview.conflictCount),
      summaryRow("Lỗi", preview.errorCount),
    ]),
  ];

  if (preview.conflictCount > 0) {
    sheetChildren.push(
      el("div", {}, [
        el("div", { class: "section-label", text: "Xử lý xung đột" }),
        el("div", { class: "chips strat-chips" }, [
          stratChip("skipExisting", "Bỏ qua"),
          stratChip("replaceExisting", "Thay thế"),
        ]),
      ]),
    );
  }

  if (!preview.canImport) {
    sheetChildren.push(
      el("div", { class: "empty-state", text: "Không có dòng nào để nhập." }),
    );
  }

  sheet.append(
    ...sheetChildren,
    el("div", { class: "btn-row", style: "margin-top:20px" }, [
      el("button", {
        class: "btn primary block",
        text: "Nhập",
        ...(preview.canImport ? {} : { disabled: "disabled" }),
        onClick: async () => {
          try {
            const r = await app.csvService.executeImport(preview, strategy);
            toast(`Tạo ${r.created} · Thay ${r.replaced} · Bỏ ${r.skipped} · OFF ${r.offDays}`);
            close();
            ctx.refresh();
          } catch (err) {
            toast(err instanceof Error ? err.message : "Nhập thất bại");
          }
        },
      }),
      el("button", { class: "btn ghost", text: "Hủy", onClick: close }),
    ]),
  );

  document.body.append(backdrop);
}

function summaryRow(label: string, value: number): HTMLElement {
  return el("div", { class: "row", style: "padding:6px 0" }, [
    el("span", { class: "muted", text: label }),
    el("span", { style: "font-weight:700", text: String(value) }),
  ]);
}
