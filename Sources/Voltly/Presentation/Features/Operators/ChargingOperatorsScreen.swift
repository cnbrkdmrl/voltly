import SwiftUI

public struct ChargingOperatorsScreen: View {
    @StateObject private var viewModel: ChargingOperatorsViewModel

    public init(viewModel: ChargingOperatorsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            if viewModel.filteredVisibleOperators.isEmpty && viewModel.filteredHiddenOperators.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Operatör bulunamadı",
                        systemImage: "magnifyingglass",
                        description: Text("Arama kriterini değiştirerek tekrar dene.")
                    )
                }
            } else {
                if !viewModel.favoriteOperators.isEmpty {
                    Section("Favoriler") {
                        ForEach(viewModel.favoriteOperators) { item in
                            operatorRow(item)
                        }
                    }
                }

                if !viewModel.nonFavoriteOperators.isEmpty {
                    Section("Operatörler") {
                        ForEach(viewModel.nonFavoriteOperators) { item in
                            operatorRow(item)
                        }
                    }
                }

                if !viewModel.filteredHiddenOperators.isEmpty {
                    Section("Gizlenenler") {
                        ForEach(viewModel.filteredHiddenOperators) { item in
                            hiddenOperatorRow(item)
                        }
                    }
                }
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Şarj Operatörleri")
        .searchable(text: $viewModel.searchText, prompt: "Operatör ara")
        .onAppear {
            viewModel.load()
        }
    }

    private func operatorRow(_ item: ChargingOperator) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                tierBadge(item.tier)
                Spacer()
                favoriteButton(item)
                hideButton(item)
            }

            HStack(spacing: 6) {
                Text(item.operatorCode.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let stationCountLabel = viewModel.stationCountLabel(for: item) {
                    Text("• \(stationCountLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let roaming = item.supportsRoaming {
                Text(roaming ? "Roaming: Destekliyor" : "Roaming: Desteklemiyor")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func hiddenOperatorRow(_ item: ChargingOperator) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(item.operatorCode.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Göster") {
                viewModel.unhide(item)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private func tierBadge(_ tier: Int) -> some View {
        Text(viewModel.tierLabel(for: tier))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.publicACColor.opacity(0.14))
            .foregroundStyle(AppTheme.publicACColor)
            .clipShape(Capsule())
    }

    private func favoriteButton(_ item: ChargingOperator) -> some View {
        Button {
            viewModel.toggleFavorite(item)
        } label: {
            Image(systemName: item.isFavorite ? "star.fill" : "star")
                .foregroundStyle(item.isFavorite ? Color.yellow : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isFavorite ? "Favoriden çıkar" : "Favoriye ekle")
    }

    private func hideButton(_ item: ChargingOperator) -> some View {
        Button {
            viewModel.hide(item)
        } label: {
            Image(systemName: "eye.slash")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gizle")
    }
}

#if DEBUG
@MainActor
struct ChargingOperatorsScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChargingOperatorsScreen(
                viewModel: ChargingOperatorsViewModel(
                    repository: InMemoryChargingOperatorRepository()
                )
            )
        }
    }
}
#endif
