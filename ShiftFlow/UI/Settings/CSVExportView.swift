// ShiftFlow — UI Layer
// Settings/CSVExportView.swift
//
// TASK-DATA-001: CSV export screen (Settings → Dữ liệu → Xuất dữ liệu).
//
// Generates a CSV of all stored WorkDays via the existing ShiftExportService
// and presents it through the native share sheet. Export is read-only:
// it never modifies WorkDays and never includes resolved times.

import SwiftUI
import ShiftFlowDomain

struct CSVExportView: View {
    var viewModel: DataManagementViewModel

    @State private var exportURL: URL?
    @State private var generating = false

    var body: some View {
        List {
            Section {
                LabeledContent("Số ngày làm việc", value: "\(viewModel.exportableWorkDayCount())")
                LabeledContent("Định dạng", value: "CSV")
                LabeledContent("Cột", value: "Date, Shift, Task, Note")
            } footer: {
                Text("Xuất dữ liệu không bao gồm giờ làm đã tính (start/end/break). Giờ làm luôn được tính lại từ ca khi nhập.")
            }

            Section {
                if let url = exportURL {
                    ShareLink(item: url) {
                        Label("Chia sẻ file CSV", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Chia sẻ file dữ liệu CSV")
                } else {
                    Button {
                        generate()
                    } label: {
                        HStack {
                            Label("Tạo file CSV", systemImage: "doc.badge.gearshape")
                            if generating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .accessibilityLabel("Tạo file dữ liệu CSV để xuất")
                    .disabled(generating)
                }
            }
        }
        .navigationTitle("Xuất dữ liệu")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func generate() {
        generating = true
        defer { generating = false }
        guard let content = viewModel.makeExportContent() else { return }
        exportURL = try? CSVFileWriter.write(
            content: content,
            fileName: viewModel.exportFileName()
        )
    }
}
