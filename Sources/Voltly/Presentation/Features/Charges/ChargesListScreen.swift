import SwiftUI

public struct ChargesListScreen: View {
    @StateObject private var viewModel: ChargesListViewModel
    @State private var editingSession: ChargingSession?
    @State private var selectedSessionForDetail: ChargingSession?

    public init(viewModel: ChargesListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            List {
                filterHeader
                if viewModel.sessions.isEmpty {
                    EmptyStateView(
                        title: viewModel.allSessionCount == 0 ? "Henüz şarj kaydı eklenmedi" : "Bu filtrede kayıt bulunamadı",
                        subtitle: viewModel.allSessionCount == 0
                            ? "Ev, AC veya DC şarjlarını kaydederek maliyet analizini gör."
                            : "Filtreyi değiştirerek farklı şarj kayıtlarını görüntüleyebilirsin.",
                        iconName: viewModel.allSessionCount == 0 ? "bolt.fill" : "line.3.horizontal.decrease.circle"
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.sessions) { session in
                        sessionRow(session)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Sil", role: .destructive) {
                                    viewModel.delete(session)
                                }
                                Button("Düzenle") {
                                    editingSession = session
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(L10n.charges)
            .toolbar {
                ToolbarItem(placement: .voltlyPrimaryAction) {
                    NavigationLink {
                        ChargeMapScreen(viewModel: viewModel.makeMapViewModel())
                    } label: {
                        Image(systemName: "map")
                    }
                    .accessibilityLabel(L10n.chargeMap)
                }
            }
            .onAppear {
                viewModel.load()
            }
            .onChange(of: viewModel.selectedMethod) { _, _ in
                viewModel.load()
            }
            .onChange(of: viewModel.selectedDateFilter) { _, _ in
                viewModel.load()
            }
            .onChange(of: viewModel.selectedSort) { _, _ in
                viewModel.load()
            }
            .sheet(item: $editingSession) { session in
                NavigationStack {
                    AddChargeScreen(viewModel: viewModel.makeEditViewModel(for: session)) {
                        editingSession = nil
                        viewModel.load()
                    }
                    .toolbar {
                        ToolbarItem(placement: .voltlyPrimaryAction) {
                            Button("Kapat") {
                                editingSession = nil
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedSessionForDetail) { session in
                NavigationStack {
                    ChargingSessionDetailScreen(
                        session: session,
                        scoreReport: viewModel.sessionScores[session.id]
                    )
                    .toolbar {
                        ToolbarItem(placement: .voltlyPrimaryAction) {
                            Button("Kapat") {
                                selectedSessionForDetail = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Yontem", selection: $viewModel.selectedMethod) {
                Text("Tum")
                    .tag(ChargeMethod?.none)
                ForEach(ChargeMethod.allCases) { method in
                    Text(method.titleTR)
                        .tag(Optional(method))
                }
            }
            .pickerStyle(.segmented)

            Picker("Donem", selection: $viewModel.selectedDateFilter) {
                ForEach(ChargeDateFilter.allCases) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Siralama", selection: $viewModel.selectedSort) {
                ForEach(ChargeSortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func sessionRow(_ session: ChargingSession) -> some View {
        ChargingSessionRowCard(
            session: session,
            scoreReport: viewModel.sessionScores[session.id]
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            selectedSessionForDetail = session
        }
    }
}

private struct ChargingSessionDetailScreen: View {
    let session: ChargingSession
    let scoreReport: ChargeSessionScoreReport?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ChargingSessionRowCard(session: session, scoreReport: scoreReport)

                if let scoreReport {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("Seans rozeti")
                                .font(.subheadline.weight(.semibold))
                            ChargeSessionScoreBadge(report: scoreReport)
                            Spacer(minLength: 0)
                        }

                        Text(ChargeSessionScoringText.scoreSummary(
                            score: scoreReport.overallScore,
                            label: scoreReport.label
                        ))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                        Text(ChargeSessionScoringText.postSaveMessage(for: scoreReport))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }
                    .padding()
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
                }

                detailMetrics
            }
            .padding()
        }
        .navigationTitle("Şarj detayı")
    }

    private var detailMetrics: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow(title: "Yöntem", value: session.chargeMethod.titleTR)
            detailRow(title: "İstasyon", value: session.stationDisplayName)
            detailRow(title: "Tarih", value: NumberFormatting.dateTime(session.sessionDate))
            detailRow(title: "Toplam", value: NumberFormatting.currency(session.priceTotal, code: session.currencyCode))
            detailRow(
                title: "Enerji",
                value: session.energyKWh.map(NumberFormatting.kWh) ?? "—"
            )
            detailRow(
                title: "Şarj aralığı",
                value: "\(Int(session.socStart))% → \(Int(session.socEnd))%"
            )
            detailRow(
                title: "Süre",
                value: session.durationMin.map { "\($0) dk" } ?? "—"
            )
            if let notes = session.notes, !notes.isEmpty {
                detailRow(title: "Not", value: notes)
            }
        }
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
