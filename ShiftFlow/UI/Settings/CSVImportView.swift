// ShiftFlow — UI Layer
// Settings/CSVImportView.swift
//
// TASK-DATA-001: CSV import screen (Settings → Dữ liệu → Nhập dữ liệu).
//
// Flow: file picker → parse+validate (existing services) → preview → confirm → execute.
// Supported: .csv, .txt. Not supported: .xlsx (rejected with a friendly message).
//
// All parsing/validation/execution is delegated to DataManagementViewModel,
// which reuses ShiftImportService → WorkDayService → ShiftResolver.

import SwiftUI
import UniformTypeIdentifiers
import ShiftFlowDomain

struct CSVImportView: View {
    var viewModel: DataManagementViewModel

    @State private var showFileImporter = false
    @State private var showPreview = false

    /// Allowed content types: CSV and plain text (some pickers surface .txt CSVs).
    private var allowedTypes: [UTType] {
        [.commaSeparatedText, .plainText, .text]
    }

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.reset()
                    showFileImporter = true
                } label: {
                    Label("Chọn file CSV", systemImage: "folder")
                }
                .accessibilityLabel("Chọn file CSV để nhập")
            } footer: {
                Text("Chọn file CSV (.csv hoặc .txt) với các cột: Date, Shift, Task, Note.")
            }

            Section {
                Label {
                    Text("Định dạng ngày: DD/MM/YYYY")
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                Label {
                    Text("Ca: C1, C2, C3, C4, C5, OFF")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                Label {
                    Text("Nhiều công việc: ngăn cách bằng dấu chấm phẩy (MW;Ticket)")
                } icon: {
                    Image(systemName: "checklist")
                }
                .font(.caption)
            } header: {
                Text("Hướng dẫn")
            }
        }
        .navigationTitle("Nhập dữ liệu")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handlePicked(result)
        }
        .navigationDestination(isPresented: $showPreview) {
            if let preview = viewModel.preview {
                CSVImportPreviewView(viewModel: viewModel, preview: preview)
            }
        }
        .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil && !showPreview)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func handlePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Access security-scoped resource for files outside the app sandbox.
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            if viewModel.prepareImport(url: url) {
                showPreview = true
            }
        case .failure:
            viewModel.errorMessage = "Không thể đọc tệp. Vui lòng thử lại."
        }
    }
}
