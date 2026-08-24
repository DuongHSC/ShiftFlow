// ShiftFlow — UI Layer
// Settings/DataManagementView.swift
//
// TASK-DATA-001: Data Management hub (Settings → Dữ liệu).
//
// Navigation:
//   Settings → Dữ liệu
//       → Xuất dữ liệu       (CSVExportView)
//       → Nhập dữ liệu       (CSVImportView)
//       → Tải mẫu CSV        (share empty template)
//
// This view only presents navigation and delegates all work to
// DataManagementViewModel, which reuses the existing import/export services.
// No parsing, validation, or shift-resolution logic lives here.

import SwiftUI
import ShiftFlowDomain

struct DataManagementView: View {
    var viewModel: DataManagementViewModel

    var body: some View {
        List {
            Section {
                NavigationLink {
                    CSVImportView(viewModel: viewModel)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nhập dữ liệu")
                            Text("Nhập lịch làm việc từ file CSV.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                .accessibilityLabel("Nhập dữ liệu CSV")

                NavigationLink {
                    CSVExportView(viewModel: viewModel)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Xuất dữ liệu")
                            Text("Xuất toàn bộ lịch làm việc ra file CSV.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .accessibilityLabel("Xuất dữ liệu CSV")

                CSVTemplateShareRow(viewModel: viewModel)
            } footer: {
                Text("File CSV có định dạng: Date, Shift, Task, Note. Có thể mở và chỉnh sửa bằng Microsoft Excel.")
            }
        }
        .navigationTitle("Dữ liệu")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Template Share Row

/// A row that shares the empty official CSV template via the native share sheet.
///
/// The template file is materialized once (on appear) rather than on every
/// redraw, so repeated UI updates do not trigger repeated disk writes.
private struct CSVTemplateShareRow: View {
    var viewModel: DataManagementViewModel

    @State private var templateURL: URL?

    var body: some View {
        Group {
            if let fileURL = templateURL {
                ShareLink(item: fileURL) {
                    templateLabel
                }
                .accessibilityLabel("Tải mẫu CSV")
            } else {
                templateLabel
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Tải mẫu CSV")
            }
        }
        .onAppear {
            if templateURL == nil {
                templateURL = try? CSVFileWriter.write(
                    content: viewModel.makeTemplateContent(),
                    fileName: viewModel.templateFileName
                )
            }
        }
    }

    private var templateLabel: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tải mẫu CSV")
                Text("Tạo file mẫu trống để điền lịch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "doc.badge.plus")
        }
    }
}
