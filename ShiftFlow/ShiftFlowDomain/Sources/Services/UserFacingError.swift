// ShiftFlow — Domain Layer
// Services/UserFacingError.swift
//
// TASK-POLISH-001: Maps internal errors to user-friendly Vietnamese messages.
//
// Ensures NO raw error types, CloudKit codes, class names, UUIDs, or stack
// traces are ever shown to the user. This is a pure, testable mapping.

import Foundation

/// Maps internal errors to user-facing Vietnamese messages.
///
/// UI layers should present `UserFacingError.message(for:)` instead of
/// `error.localizedDescription` or the raw error.
public enum UserFacingError {

    /// Returns a user-friendly Vietnamese message for any error.
    ///
    /// Known ShiftFlow errors get specific messages; anything else falls back
    /// to a safe generic message that never leaks technical detail.
    public static func message(for error: Error) -> String {
        // WorkDay repository errors.
        if let repoError = error as? WorkDayRepositoryError {
            return message(for: repoError)
        }
        // Import parse errors.
        if let parseError = error as? ImportParseError {
            return message(for: parseError)
        }
        // Shift configuration errors.
        if let configError = error as? ShiftConfigurationError {
            return message(for: configError)
        }
        // Task errors.
        if let taskError = error as? TaskError {
            return message(for: taskError)
        }
        // Unknown/system error — never leak details.
        return "Đã xảy ra lỗi. Vui lòng thử lại."
    }

    /// Message for a task error.
    public static func message(for error: TaskError) -> String {
        switch error {
        case .emptyCode:
            return "Mã công việc không được để trống."
        case .emptyName:
            return "Tên công việc không được để trống."
        case .duplicateCode:
            return "Mã công việc đã tồn tại."
        case .notFound:
            return "Không tìm thấy công việc."
        case .taskInUse:
            return "Công việc đang được sử dụng. Hãy tắt thay vì xóa."
        }
    }

    /// Message for a shift configuration error.
    public static func message(for error: ShiftConfigurationError) -> String {
        switch error {
        case .startNotBeforeEnd:
            return "Giờ bắt đầu phải trước giờ kết thúc."
        case .breakStartNotBeforeBreakEnd:
            return "Giờ bắt đầu nghỉ phải trước giờ kết thúc nghỉ."
        case .breakOutsideWorkingInterval:
            return "Thời gian nghỉ phải nằm trong thời gian làm việc."
        case .emptyName:
            return "Tên ca không được để trống."
        case .duplicateCode:
            return "Mã ca đã tồn tại."
        case .notFound:
            return "Không tìm thấy cấu hình ca."
        case .invalidDayRange:
            return "Khoảng ngày không hợp lệ (1–31, ngày bắt đầu ≤ ngày kết thúc)."
        }
    }

    /// Message for a WorkDay repository error.
    public static func message(for error: WorkDayRepositoryError) -> String {
        switch error {
        case .duplicateDate:
            return "Ngày này đã có ca làm việc."
        case .notFound:
            return "Không tìm thấy ca làm việc."
        case .persistenceFailed:
            return "Không thể lưu. Vui lòng thử lại."
        }
    }

    /// Message for an import parse error.
    public static func message(for error: ImportParseError) -> String {
        switch error {
        case .emptyFile:
            return "Tệp trống hoặc không có dữ liệu."
        case .invalidHeader:
            return "Tệp không đúng định dạng. Cần các cột: Date, Shift, Task, Note."
        case .unsupportedFormat:
            return "Định dạng tệp không được hỗ trợ. Vui lòng dùng tệp Excel (.xlsx)."
        case .readFailed:
            return "Không thể đọc tệp. Vui lòng thử lại."
        }
    }

    /// Message for a CloudKit/sync failure (device-agnostic).
    public static func syncUnavailableMessage() -> String {
        "Không thể đồng bộ lúc này. Dữ liệu trên thiết bị vẫn được lưu."
    }

    /// Message for denied notification permission.
    public static func notificationDeniedMessage() -> String {
        "Thông báo đang bị tắt. Bạn có thể bật lại trong Cài đặt iPhone."
    }
}
