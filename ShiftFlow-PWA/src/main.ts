// ShiftFlow PWA — Entry Point
// src/main.ts
//
// Startup flow (local-first):
//   PWA opens -> seed IndexedDB if needed -> render UI from IndexedDB.
// No network, no remote API, no manual "Load Data" required for normal startup.

import "@/styles/styles.css";
import { app } from "@/services/appContainer";
import { Router, type ScreenId } from "@/ui/navigation/router";
import { renderUpcoming } from "@/ui/screens/upcomingScreen";
import { renderToday } from "@/ui/screens/todayScreen";
import { renderCalendar } from "@/ui/screens/calendarScreen";
import { renderSettings, resetSettingsView } from "@/ui/screens/settingsScreen";
import { el } from "@/ui/components/dom";

async function boot(): Promise<void> {
  const root = document.getElementById("app");
  if (!root) return;

  try {
    await app.bootstrap();
  } catch (err) {
    root.append(
      el("div", { class: "screen" }, [
        el("h1", { class: "screen-title", text: "ShiftFlow" }),
        el("div", { class: "empty-state", text: "Không thể mở cơ sở dữ liệu cục bộ." }),
        el("div", { class: "tiny", text: err instanceof Error ? err.message : String(err) }),
      ]),
    );
    return;
  }

  const router = new Router(
    root,
    {
      upcoming: renderUpcoming,
      calendar: renderCalendar,
      settings: renderSettings,
      today: renderToday,
    },
    {
      // Tapping the "Cài đặt" tab always returns to Settings root.
      settings: resetSettingsView,
    },
  );

  const initial = (location.hash.replace("#", "") as ScreenId) || "upcoming";
  await router.start(
    ["upcoming", "calendar", "settings", "today"].includes(initial)
      ? initial
      : "upcoming",
  );
}

void boot();
