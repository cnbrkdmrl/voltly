import SwiftUI

struct LocationPickerSheet: View {
    let selectedLocation: String
    let locations: [String]
    let onSelect: (String) -> Void
    let onClearSelection: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            List {
                if !selectedLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Button {
                            onClearSelection()
                        } label: {
                            Label("Seçimi temizle", systemImage: "xmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Lokasyonlar") {
                    if filteredLocations.isEmpty {
                        Text("Sonuç bulunamadı")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredLocations, id: \.self) { location in
                            locationRow(location)
                        }
                    }
                }

                if let customLocationCandidate {
                    Section {
                        Button {
                            onSelect(customLocationCandidate)
                            dismiss()
                        } label: {
                            Label("\"\(customLocationCandidate)\" ekle", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .navigationTitle("Lokasyon Seç")
            .searchable(text: $searchText, prompt: "Lokasyon ara")
            .toolbar {
                ToolbarItem(placement: .voltlyPrimaryAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredLocations: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return locations }
        return locations.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var customLocationCandidate: String? {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let exists = locations.contains {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased() == query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
        }
        return exists ? nil : query
    }

    private func locationRow(_ location: String) -> some View {
        Button {
            onSelect(location)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(location)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedLocation.localizedCaseInsensitiveCompare(location) == .orderedSame {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.publicACColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
struct LocationPickerSheet_Previews: PreviewProvider {
    static var previews: some View {
        LocationPickerSheet(
            selectedLocation: "Zorlu AVM Otopark - B2",
            locations: [
                "Zorlu AVM Otopark - B2",
                "Forum Ankara - A Blok",
                "Piazza Avm - Kat 2"
            ],
            onSelect: { _ in },
            onClearSelection: {}
        )
    }
}
#endif
