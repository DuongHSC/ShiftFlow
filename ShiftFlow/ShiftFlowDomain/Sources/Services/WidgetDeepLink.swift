// ShiftFlow — Domain Layer
// Services/WidgetDeepLink.swift
//
// TASK-WIDGET-001: Widget deep-link contract.
//
// Defines the URL contract for widget tap actions.
// Simple URL scheme — no authentication, no networking.
//
// shiftflow://day?date=<yyyy-MM-dd>
// Widget tap → opens main app at the relevant day (today, or next shift).

import Foundation

/// Deep-link URL contract between the Widget and the main app.
public enum WidgetDeepLink {

    /// URL scheme.
    public static let scheme = "shiftflow"

    /// Host for the "open day" action.
    public static let dayHost = "day"

    /// Query parameter name for the date.
    public static let dateParam = "date"

    private static let dateFormat = "yyyy-MM-dd"

    /// Builds a deep-link URL for a specific date.
    public static func url(forDate date: Date, calendar: Calendar = .current) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.calendar = calendar
        // Format in the calendar's own time zone. WorkDay dates are local-midnight
        // values in that zone; without this the system zone (UTC on CI) shifts the
        // rendered yyyy-MM-dd to the previous day. Keeps deep-link round-trip stable.
        formatter.timeZone = calendar.timeZone
        let dateString = formatter.string(from: date)

        var components = URLComponents()
        components.scheme = scheme
        components.host = dayHost
        components.queryItems = [URLQueryItem(name: dateParam, value: dateString)]
        return components.url
    }

    /// Builds the appropriate deep-link URL from a widget snapshot.
    ///
    /// Prefers today's date; falls back to next shift; nil if neither exists.
    public static func url(for snapshot: WidgetScheduleSnapshot, calendar: Calendar = .current) -> URL? {
        if let today = snapshot.today {
            return url(forDate: today.date, calendar: calendar)
        }
        if let next = snapshot.nextShift {
            return url(forDate: next.date, calendar: calendar)
        }
        // No schedule — open today (empty day).
        return url(forDate: Date(), calendar: calendar)
    }

    /// Parses a deep-link URL back into a date.
    /// Returns nil if the URL is not a valid ShiftFlow day link.
    public static func parseDate(from url: URL, calendar: Calendar = .current) -> Date? {
        guard url.scheme == scheme,
              url.host == dayHost,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dateString = components.queryItems?.first(where: { $0.name == dateParam })?.value else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.calendar = calendar
        // Parse in the same time zone used to format (symmetric round-trip).
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: dateString)
    }
}
