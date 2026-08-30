import SwiftUI
import UniformTypeIdentifiers

public struct BackupSettingsView: View {
    @StateObject private var viewModel: BackupSettingsViewModel
    #if os(iOS)
    @State private var shareSheetFile: ShareSheetFile?
    #endif

    public init(viewModel: BackupSettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            exportSection
            importSection
            lastExportSection
            if let result = viewModel.lastImportResult {
                importSummarySection(result)
            }
            statusSection
        }
        .navigationTitle("Data & Backup")
        .disabled(viewModel.isPerformingAction)
        .overlay(alignment: .center) {
            if viewModel.isPerformingAction {
                ProgressView("İşlem yapılıyor...")
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .fileImporter(
            isPresented: $viewModel.isShowingImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            viewModel.handleImportSelection(result)
        }
        .alert(item: $viewModel.alertState) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("Tamam"))
            )
        }
        #if os(iOS)
        .sheet(item: $shareSheetFile) { item in
            FileShareSheetView(items: [item.url])
        }
        #endif
    }

    private var exportSection: some View {
        Section("Dışa Aktar") {
            Button {
                viewModel.exportFullBackupJSON()
            } label: {
                Label("Tam Yedeği Dışa Aktar (JSON)", systemImage: "tray.and.arrow.up")
            }

            Button {
                viewModel.exportChargingSessionsCSV()
            } label: {
                Label("Şarj Kayıtlarını Dışa Aktar (CSV)", systemImage: "tablecells.badge.ellipsis")
            }

            Button {
                viewModel.exportFullBackupToICloudDrive()
            } label: {
                Label("iCloud Drive'a Yedekle (JSON)", systemImage: "icloud.and.arrow.up")
            }

            if let fileURL = viewModel.shareFileURL {
                #if os(iOS)
                Button {
                    presentShareSheet(for: fileURL)
                } label: {
                    Label("Son Dosyayı Paylaş", systemImage: "square.and.arrow.up")
                }
                #else
                ShareLink(item: fileURL) {
                    Label("Son Dosyayı Paylaş", systemImage: "square.and.arrow.up")
                }
                #endif
            }
        }
    }

    private var importSection: some View {
        Section("İçe Aktar") {
            Button {
                viewModel.startImportFlow()
            } label: {
                Label("Yedeği İçe Aktar (JSON)", systemImage: "tray.and.arrow.down")
            }

            if let lastImportedFileName = viewModel.lastImportedFileName {
                LabeledContent("Son içe aktarılan dosya", value: lastImportedFileName)
                    .font(.footnote)
            }
        }
    }

    private var lastExportSection: some View {
        Section("Son Dışa Aktarım") {
            if let info = viewModel.lastExportInfo {
                LabeledContent("Dosya", value: info.fileName)
                LabeledContent("Tür", value: info.kind.title)
                LabeledContent("Tarih", value: CSVValueFormatter.date(info.date))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Henüz dışa aktarım yapılmadı")
                        .font(.subheadline.weight(.semibold))
                    Text("JSON veya CSV export işlemi sonrası burada görünecek.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func importSummarySection(_ result: BackupImportResult) -> some View {
        Section("İçe Aktarım Özeti") {
            summaryRow("Eklenen", value: result.insertedCount)
            summaryRow("Güncellenen", value: result.updatedCount)
            summaryRow("Atlanan", value: result.skippedCount)
            summaryRow("Hata", value: result.failedCount)

            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Uyarılar")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(result.warnings.prefix(5).enumerated()), id: \.offset) { _, warning in
                        Text("• \(warning)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if result.warnings.count > 5 {
                        Text("+\(result.warnings.count - 5) uyarı daha")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var statusSection: some View {
        Section("Durum") {
            if let message = viewModel.statusMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color(for: message.style))
                    Text(message.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } else {
                Text("Henüz bir işlem yapılmadı.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryRow(_ title: String, value: Int) -> some View {
        LabeledContent(title, value: String(value))
    }

    private func color(for style: BackupStatusStyle) -> Color {
        switch style {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

#if os(iOS)
private extension BackupSettingsView {
    func presentShareSheet(for fileURL: URL) {
        shareSheetFile = ShareSheetFile(url: fileURL)
    }
}

private struct ShareSheetFile: Identifiable {
    let id = UUID()
    let url: URL
}
#endif

#if DEBUG
struct BackupSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BackupSettingsView(viewModel: .preview())
        }
    }
}
#endif
