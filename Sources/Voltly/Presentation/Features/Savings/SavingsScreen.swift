import SwiftUI

public struct SavingsScreen: View {
    @StateObject private var viewModel: SavingsViewModel

    public init(viewModel: SavingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !viewModel.hasActiveVehicle {
                        EmptyStateView(
                            title: "Tasarruf analizi için aktif araç gerekli",
                            subtitle: "Ayarlar > Araç Yönetimi ekranından aktif aracı seç.",
                            iconName: "car.fill"
                        )
                    } else if viewModel.totalSessionCount == 0 {
                        EmptyStateView(
                            title: "Henüz tasarruf verisi yok",
                            subtitle: "İlk şarj kaydından sonra tasarruf ve karşılaştırma kartların burada görünür.",
                            iconName: "banknote"
                        )
                    } else {
                        savingsOverview
                        planImpactCard
                        if viewModel.savingsBankV2Enabled {
                            piggyBankV2
                        } else {
                            piggyBank
                        }
                        carbonModule
                        shareCard
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.savings)
            .onAppear {
                viewModel.load()
                #if os(iOS)
                viewModel.renderShareCard()
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .voltlyDataDidChange)) { _ in
                viewModel.load()
                #if os(iOS)
                viewModel.renderShareCard()
                #endif
            }
        }
    }

    private var savingsOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tasarruf Ozeti")
                .font(.headline)

            metricRow("\(viewModel.primaryPeriodTitle.capitalized) EV harcama", NumberFormatting.currency(viewModel.monthlyEVSpendTL, code: viewModel.currencyCode))
            metricRow("\(viewModel.primaryPeriodTitle.capitalized) benzin esitdegeri", NumberFormatting.currency(viewModel.monthlyGasolineTL, code: viewModel.currencyCode))
            metricRow("\(viewModel.primaryPeriodTitle.capitalized) tasarruf", NumberFormatting.currency(viewModel.monthlySavingsTL, code: viewModel.currencyCode), highlight: true)
            metricRow("Tasarruf yuzdesi", viewModel.gasolineComparisonText, highlight: true)
            metricRow("Tum zamanlar tasarruf", NumberFormatting.currency(viewModel.allTimeSavingsTL, code: viewModel.currencyCode))
            if !viewModel.calculationExplanation.isEmpty {
                Text(viewModel.calculationExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var piggyBank: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasarruf Kumbarasi")
                .font(.headline)

            if viewModel.equivalentItems.isEmpty {
                Text("Karsilastirma olusmasi icin tasarruf verisi gerekli.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.equivalentItems) { item in
                    HStack {
                        Text("Yaklaşık \(item.value) \(item.title)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var planImpactCard: some View {
        if let headline = viewModel.planImpactHeadline {
            VStack(alignment: .leading, spacing: 10) {
                Text("Bu ay planın etkisi")
                    .font(.headline)

                Text(headline)
                    .font(.subheadline.weight(.semibold))

                if let detail = viewModel.planImpactDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let plan = viewModel.activePlan {
                    ProgressView(value: plan.progress.fraction, total: 1)
                        .tint(AppTheme.publicACColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var piggyBankV2: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Tasarruf Kumbarası")
                    .font(.headline)
                Text("V2")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(AppTheme.publicACColor.opacity(0.18))
                    .foregroundStyle(AppTheme.publicACColor)
                    .clipShape(Capsule())
            }

            if viewModel.equivalentItems.isEmpty {
                Text("Karsilastirma olusmasi icin tasarruf verisi gerekli.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.equivalentItems) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppTheme.publicACColor)
                            .font(.caption.weight(.semibold))
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Yaklaşık \(item.value) \(item.title)")
                                .font(.subheadline.weight(.semibold))
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if item.id != viewModel.equivalentItems.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var carbonModule: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Karbon Kacinimi")
                    .font(.headline)
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
            }

            Text("Toplam CO2 tasarrufu")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(NumberFormatting.oneDecimal(viewModel.allTimeCO2AvoidedKG)) kg CO2")
                .font(.title3.weight(.semibold))

            HStack(alignment: .center, spacing: 10) {
                Text("≈ \(viewModel.allTimeTreeEquivalent) agac")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.homeColor)

                if viewModel.allTimeTreeEquivalent > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: -8) {
                            ForEach(0..<viewModel.allTimeTreeEquivalent, id: \.self) { index in
                                Image(systemName: "tree.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green.opacity(iconOpacity(for: index)))
                                    .padding(6)
                                    .background(AppTheme.elevatedSurface.opacity(0.9))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.green.opacity(0.15), lineWidth: 1)
                                    )
                                    .zIndex(Double(viewModel.allTimeTreeEquivalent - index))
                            }
                        }
                        .padding(.trailing, 8)
                    }
                    .frame(height: 32)
                }
            }

            Text("Bu ay: \(NumberFormatting.oneDecimal(viewModel.monthlyCO2AvoidedKG)) kg CO2")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paylaşılabilir Kart")
                .font(.headline)

            SavingsShareCardView(content: viewModel.shareCardContent)
            .frame(height: 420)

            #if os(iOS)
            if let image = viewModel.shareImage,
               let imageData = image.pngData() {
                ShareLink(
                    item: imageData,
                    preview: SharePreview("Voltly Bu Ay Tasarruf", image: Image(uiImage: image))
                ) {
                    Label("9:16 Karti Paylas", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            #endif

            ShareLink(item: viewModel.shareCopy) {
                Label("Paylasim Metnini Paylas", systemImage: "text.quote")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metricRow(_ title: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(highlight ? AppTheme.homeColor : .primary)
        }
        .font(.subheadline)
    }

    private func iconOpacity(for index: Int) -> Double {
        let cycle = index % 3
        switch cycle {
        case 0:
            return 1
        case 1:
            return 0.86
        default:
            return 0.72
        }
    }
}
