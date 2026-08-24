// ShiftFlow — Tests
// PolishTests.swift
//
// TASK-POLISH-001: Quality/polish tests.
//
// Verifies user-facing error mapping, empty-state messaging, color-independence
// invariants (shift code always available as text), Vietnamese weekday labels,
// and that no technical error detail leaks to users.
//
// UI rendering, Dark Mode, and Dynamic Type are verified physically on macOS.

import XCTest
@testable import ShiftFlowDomain

final class PolishTests: XCTestCase {

    // MARK: - Infrastructure

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = 0; c.minute = 0; c.second = 0
        return calendar.date(from: c)!
    }

    private var c5: ShiftDefinition { ShiftSeedProvider.makeC5() }
    private var c5Rules: [ScheduleRule] { [ShiftSeedProvider.makeC5SpecialRule()] }

    // MARK: - User-Facing Error Mapping

    func testDuplicateDateErrorMessage() {
        let error = WorkDayRepositoryError.duplicateDate(makeDate(year: 2026, month: 8, day: 15))
        let msg = UserFacingError.message(for: error)
        XCTAssertEqual(msg, "Ngày này đã có ca làm việc.")
    }

    func testNotFoundErrorMessage() {
        let error = WorkDayRepositoryError.notFound(UUID())
        let msg = UserFacingError.message(for: error)
        XCTAssertEqual(msg, "Không tìm thấy ca làm việc.")
    }

    func testPersistenceFailedErrorMessage() {
        let error = WorkDayRepositoryError.persistenceFailed("SQLITE_BUSY code 5")
        let msg = UserFacingError.message(for: error)
        XCTAssertEqual(msg, "Không thể lưu. Vui lòng thử lại.")
        // Ensure raw detail is NOT leaked.
        XCTAssertFalse(msg.contains("SQLITE"))
        XCTAssertFalse(msg.contains("5"))
    }

    func testImportEmptyFileMessage() {
        let msg = UserFacingError.message(for: ImportParseError.emptyFile)
        XCTAssertEqual(msg, "Tệp trống hoặc không có dữ liệu.")
    }

    func testImportInvalidHeaderMessage() {
        let msg = UserFacingError.message(for: ImportParseError.invalidHeader)
        XCTAssertTrue(msg.contains("Date, Shift, Task, Note"))
    }

    func testImportUnsupportedFormatMessage() {
        let msg = UserFacingError.message(for: ImportParseError.unsupportedFormat)
        XCTAssertTrue(msg.contains(".xlsx"))
    }

    func testUnknownErrorFallbackDoesNotLeakDetail() {
        struct SecretError: Error { let internalCode = "DB-INTERNAL-42" }
        let msg = UserFacingError.message(for: SecretError())
        XCTAssertEqual(msg, "Đã xảy ra lỗi. Vui lòng thử lại.")
        XCTAssertFalse(msg.contains("DB-INTERNAL"))
        XCTAssertFalse(msg.contains("SecretError"))
    }

    func testSyncUnavailableMessage() {
        let msg = UserFacingError.syncUnavailableMessage()
        XCTAssertEqual(msg, "Không thể đồng bộ lúc này. Dữ liệu trên thiết bị vẫn được lưu.")
    }

    func testNotificationDeniedMessage() {
        let msg = UserFacingError.notificationDeniedMessage()
        XCTAssertTrue(msg.contains("Cài đặt"))
    }

    func testNoTechnicalErrorExposedForAnyRepositoryError() {
        // Every WorkDayRepositoryError must map to a message with no code/type name.
        let errors: [WorkDayRepositoryError] = [
            .duplicateDate(Date()),
            .notFound(UUID()),
            .persistenceFailed("raw technical detail")
        ]
        for e in errors {
            let msg = UserFacingError.message(for: e)
            XCTAssertFalse(msg.contains("Error"))
            XCTAssertFalse(msg.contains("WorkDayRepository"))
            XCTAssertFalse(msg.lowercased().contains("uuid"))
        }
    }

    // MARK: - Color Independence (shift code always available as text)

    func testShiftCodeAlwaysNonEmpty() {
        for def in ShiftSeedProvider.allDefaultShifts() {
            XCTAssertFalse(def.code.isEmpty, "Shift \(def.name) must have a text code")
        }
    }

    func testValidShiftCodesAreTextual() {
        let codes = ShiftSeedProvider.allDefaultShifts().map { $0.code }
        XCTAssertEqual(Set(codes), ["C1", "C2", "C3", "C4", "C5"])
    }

    func testResolvedShiftCarriesTextualCode() {
        let resolved = ShiftResolver.resolve(
            date: makeDate(year: 2026, month: 8, day: 15),
            shift: c5, rules: c5Rules, calendar: calendar
        )
        XCTAssertEqual(resolved.shiftCode, "C5", "Resolved shift must carry text code, not color")
    }

    // MARK: - Vietnamese Weekday Labels

    func testFullWeekdayNames() {
        XCTAssertEqual(WeekdayFormatter.fullName(for: 2), "Thứ 2")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 3), "Thứ 3")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 4), "Thứ 4")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 5), "Thứ 5")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 6), "Thứ 6")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 7), "Thứ 7")
        XCTAssertEqual(WeekdayFormatter.fullName(for: 1), "Chủ nhật")
    }

    func testShortWeekdayNames() {
        XCTAssertEqual(WeekdayFormatter.shortName(for: 2), "T2")
        XCTAssertEqual(WeekdayFormatter.shortName(for: 1), "CN")
    }

    func testMondayFirstHeader() {
        XCTAssertEqual(WeekdayFormatter.mondayFirstShortNames, ["T2", "T3", "T4", "T5", "T6", "T7", "CN"])
    }

    // MARK: - Accessibility Labels

    func testWorkDayAccessibilityLabelContainsShiftCodeAndTimes() {
        let date = makeDate(year: 2026, month: 8, day: 19) // Wednesday
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)
        let wd = WorkDay(date: date, resolvedShift: resolved)

        let label = AccessibilityLabelBuilder.dayLabel(
            date: date, workDay: wd, includeBreak: true, includeNote: false, calendar: calendar
        )

        XCTAssertTrue(label.contains("Thứ 4"), "Label must include weekday")
        XCTAssertTrue(label.contains("C5"), "Label must include shift code text")
        XCTAssertTrue(label.contains("12:00"), "Label must include start time")
        XCTAssertTrue(label.contains("21:30"), "Label must include end time")
        XCTAssertTrue(label.contains("nghỉ"), "Label must include break")
    }

    func testOFFAccessibilityLabel() {
        let date = makeDate(year: 2026, month: 8, day: 19)
        let label = AccessibilityLabelBuilder.dayLabel(date: date, workDay: nil, calendar: calendar)

        XCTAssertTrue(label.contains("Thứ 4"))
        XCTAssertTrue(label.contains("OFF"))
    }

    func testAccessibilityLabelIncludesNoteWhenRequested() {
        let date = makeDate(year: 2026, month: 8, day: 19)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)
        let wd = WorkDay(date: date, resolvedShift: resolved, note: "Họp team")

        let label = AccessibilityLabelBuilder.dayLabel(
            date: date, workDay: wd, includeNote: true, calendar: calendar
        )
        XCTAssertTrue(label.contains("Họp team"))
    }

    func testNextShiftAccessibilityLabel() {
        let date = makeDate(year: 2026, month: 8, day: 20)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)
        let wd = WorkDay(date: date, resolvedShift: resolved)

        let label = AccessibilityLabelBuilder.nextShiftLabel(wd, calendar: calendar)
        XCTAssertTrue(label.contains("Ca tiếp theo"))
        XCTAssertTrue(label.contains("C5"))
    }

    func testNextShiftEmptyAccessibilityLabel() {
        let label = AccessibilityLabelBuilder.nextShiftLabel(nil, calendar: calendar)
        XCTAssertEqual(label, "Không có ca làm việc sắp tới")
    }

    // MARK: - Empty States

    func testNextShiftEmptyStateMessage() {
        // Empty next shift message must not look like an error.
        let label = AccessibilityLabelBuilder.nextShiftLabel(nil, calendar: calendar)
        XCTAssertFalse(label.lowercased().contains("lỗi"))
        XCTAssertFalse(label.lowercased().contains("error"))
    }

    // MARK: - Reminder Offset Vietnamese Labels (polish wording)

    func testReminderOffsetDisplayNamesAreVietnamese() {
        XCTAssertEqual(ReminderOffset.atStart.displayName, "Lúc bắt đầu")
        XCTAssertEqual(ReminderOffset.thirtyMinutesBefore.displayName, "30 phút trước")
        XCTAssertEqual(ReminderOffset.oneHourBefore.displayName, "1 giờ trước")
        XCTAssertEqual(ReminderOffset.twoHoursBefore.displayName, "2 giờ trước")
        XCTAssertEqual(ReminderOffset.twentyFourHoursBefore.displayName, "24 giờ trước")
    }

    // MARK: - Sync Status Vietnamese (no raw codes)

    func testSyncStatusDisplayTextIsUserFriendly() {
        for status in [SyncStatus.synced, .syncing, .waitingForConnection, .unavailable, .accountUnavailable] {
            let text = status.displayText
            XCTAssertFalse(text.isEmpty)
            XCTAssertFalse(text.contains("CK"), "No CloudKit codes")
            XCTAssertFalse(text.contains("Error"))
        }
    }

    // MARK: - Task Indicator Independence (widget data)

    func testWidgetTaskIndicatorSeparateFromShiftCode() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)
        let wd = WorkDay(date: date, resolvedShift: resolved)

        let withTask = WidgetDayEntry(from: wd, hasTask: true)
        let withoutTask = WidgetDayEntry(from: wd, hasTask: false)

        // Shift code identical; only the indicator differs.
        XCTAssertEqual(withTask.shiftCode, "C5")
        XCTAssertEqual(withoutTask.shiftCode, "C5")
        XCTAssertTrue(withTask.hasTask)
        XCTAssertFalse(withoutTask.hasTask)
        // Times identical (task never affects times).
        XCTAssertEqual(withTask.startDateTime, withoutTask.startDateTime)
    }

    // MARK: - Note Not Exposed in Widget

    func testWidgetDoesNotExposeNoteText() {
        let date = makeDate(year: 2026, month: 8, day: 15)
        let resolved = ShiftResolver.resolve(date: date, shift: c5, rules: c5Rules, calendar: calendar)
        let wd = WorkDay(date: date, resolvedShift: resolved, note: "Private meeting details")

        let entry = WidgetDayEntry(from: wd)
        // Only the hasNote indicator, never the text.
        XCTAssertTrue(entry.hasNote)
        // WidgetDayEntry has no note-text property by design (compile-time guarantee).
    }
}
