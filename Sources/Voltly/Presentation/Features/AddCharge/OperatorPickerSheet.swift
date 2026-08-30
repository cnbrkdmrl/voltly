import SwiftUI

struct OperatorPickerSheet: View {
    let selectedOperator: String
    let favoriteOperators: [EVChargeOperator]
    let otherOperators: [EVChargeOperator]
    let isFavorite: (String) -> Bool
    let onSelect: (String) -> Void
    let onToggleFavorite: (String) -> Void
    let onClearSelection: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            List {
                if !selectedOperator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Button {
                            onClearSelection()
                        } label: {
                            Label("Seçimi temizle", systemImage: "xmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !filteredFavorites.isEmpty {
                    Section("Favoriler") {
                        ForEach(filteredFavorites) { item in
                            operatorRow(item)
                        }
                    }
                }

                Section("Diğer Operatörler") {
                    if filteredOthers.isEmpty {
                        Text("Sonuç bulunamadı")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredOthers) { item in
                            operatorRow(item)
                        }
                    }
                }

                if let customOperatorCandidate {
                    Section {
                        Button {
                            onSelect(customOperatorCandidate)
                            dismiss()
                        } label: {
                            Label("\"\(customOperatorCandidate)\" ekle", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .navigationTitle("Operatör Seç")
            .searchable(text: $searchText, prompt: "Operatör ara")
            .toolbar {
                ToolbarItem(placement: .voltlyPrimaryAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredFavorites: [EVChargeOperator] {
        filterOperators(favoriteOperators)
    }

    private var filteredOthers: [EVChargeOperator] {
        filterOperators(otherOperators)
    }

    private var customOperatorCandidate: String? {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        let allNames = (favoriteOperators + otherOperators).map(\.name)
        let exists = allNames.contains {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased() == query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
        }
        return exists ? nil : query
    }

    private func filterOperators(_ operators: [EVChargeOperator]) -> [EVChargeOperator] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return operators }
        return operators.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func operatorRow(_ item: EVChargeOperator) -> some View {
        HStack(spacing: 10) {
            Button {
                onSelect(item.name)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedOperator.localizedCaseInsensitiveCompare(item.name) == .orderedSame {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.publicACColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onToggleFavorite(item.name)
            } label: {
                Image(systemName: isFavorite(item.name) ? "star.fill" : "star")
                    .foregroundStyle(isFavorite(item.name) ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite(item.name) ? "Favoriden çıkar" : "Favoriye ekle")
        }
    }
}

#if DEBUG
struct OperatorPickerSheet_Previews: PreviewProvider {
    static var previews: some View {
        OperatorPickerSheet(
            selectedOperator: "Trugo",
            favoriteOperators: [
                EVChargeOperator(name: "ZES"),
                EVChargeOperator(name: "Trugo")
            ],
            otherOperators: EVChargeOperator.turkiye.filter { !["ZES", "Trugo"].contains($0.name) },
            isFavorite: { ["ZES", "Trugo"].contains($0) },
            onSelect: { _ in },
            onToggleFavorite: { _ in },
            onClearSelection: {}
        )
    }
}
#endif
