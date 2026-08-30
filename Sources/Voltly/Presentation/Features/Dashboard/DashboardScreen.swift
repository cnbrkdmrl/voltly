import Charts
import SwiftUI

public struct DashboardScreen: View {
    @StateObject private var viewModel: DashboardViewModel
    @ObservedObject private var backupBannerCoordinator: BackupUpsellBannerCoordinator
    private let sessionState: SessionState
    private let onCreateAccountRequested: () -> Void
    private let onAddChargeRequested: () -> Void
    @State private var selectedTrendPointID: UUID?

    public init(
        viewModel: DashboardViewModel,
        sessionState: SessionState = .signedOut,
        backupBannerCoordinator: BackupUpsellBannerCoordinator? = nil,
        onCreateAccountRequested: @escaping () -> Void = {},
        onAddChargeRequested: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.sessionState = sessionState
        _backupBannerCoordinator = ObservedObject(wrappedValue: backupBannerCoordinator ?? BackupUpsellBannerCoordinator())
        self.onCreateAccountRequested = onCreateAccountRequested
        self.onAddChargeRequested = onAddChargeRequested
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if backupBannerCoordinator.isVisible {
                        BackupAccountBanner(
                            onCreateAccount: handleCreateAccountTapped,
                            onLater: handleBannerDismissed,
                            onClose: handleBannerDismissed
                        )
                    }

                    if !viewModel.hasActiveVehicle {
                        noVehicleState
                    } else if viewModel.totalSessionCount == 0 {
                        noSessionsState
                    } else {
                        if viewModel.smartRecommendationsEnabled {
                            retentionPromptSection
                            dailyInsightSection
                        }
                        heroCard
                        quickModules
                        if viewModel.betaDashboardCardsEnabled {
                            betaDashboardCardsSection
                        }
                        trendSection
                        recentSection
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.dashboard)
            .toolbar {
                ToolbarItem(placement: .voltlyPrimaryAction) {
                    NavigationLink {
                        MonthlyEVReportScreen(viewModel: viewModel.makeMonthlyEVReportViewModel())
                    } label: {
                        Image(systemName: "doc.text.image")
                    }
                    .accessibilityLabel(L10n.monthlyEVReport)
                }
            }
            .onAppear {
                viewModel.load()
                evaluateBackupBannerVisibility()
            }
            .onReceive(NotificationCenter.default.publisher(for: .voltlyDataDidChange)) { _ in
                viewModel.load()
                evaluateBackupBannerVisibility()
            }
            .onChange(of: viewModel.totalSessionCount) { _, _ in
                evaluateBackupBannerVisibility()
            }
            .onChange(of: sessionState) { _, _ in
                evaluateBackupBannerVisibility()
            }
        }
    }

    private var dailyInsightSection: some View {
        DailyInsightBanner(
            text: viewModel.dailyInsight?.text ?? "Bugün için öne çıkan yeni bir değişim yok.",
            isPlaceholder: viewModel.dailyInsight == nil
        )
    }

    @ViewBuilder
    private var retentionPromptSection: some View {
        if let prompt = viewModel.retentionPrompt {
            RetentionPromptBanner(prompt: prompt)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(viewModel.snapshot.primaryPeriodLabel) EV Maliyeti")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text(NumberFormatting.currency(viewModel.snapshot.monthlyTotalCost, code: viewModel.snapshot.currencyCode))
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                Text("\(viewModel.snapshot.currencyCode) / 100 km:")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                if let value = viewModel.snapshot.tlPer100Km {
                    Text(NumberFormatting.oneDecimal(value.value))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    EstimationBadge(isEstimated: value.isEstimated)
                } else {
                    Text("Hesaplanamadi")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            if let percent = viewModel.snapshot.gasolineSavingsPercent,
               let amount = viewModel.snapshot.gasolineSavingsAmount {
                let absPercent = abs(percent)
                if amount > 0 {
                    Text("Benzine gore \(NumberFormatting.percent(absPercent)) daha ucuz")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else if amount < 0 {
                    Text("Benzine gore \(NumberFormatting.percent(absPercent)) daha pahali")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Text("Benzin ile ayni maliyet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                Text("Tasarruf analizi için daha fazla veri gerekli")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let explanation = viewModel.snapshot.calculationExplanation,
               !explanation.isEmpty {
                Text(explanation)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.heroBackground,
                    AppTheme.publicDCColor.opacity(0.32),
                    AppTheme.dcAccent.opacity(0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .bottomTrailing) {
            if let activeVehicle = viewModel.activeVehicle {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 30, weight: .bold))
                    Text(activeVehicle.model.uppercased())
                        .font(.caption2.weight(.black))
                    Text("\(activeVehicle.brand) \(activeVehicle.year)")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.16))
                .padding(12)
            }
        }
    }

    private var quickModules: some View {
        VStack(spacing: 12) {
            TotalSavingsCard(
                amount: viewModel.snapshot.totalSavingsAmount,
                savingsPercent: viewModel.snapshot.totalSavingsPercent,
                currencyCode: viewModel.snapshot.currencyCode
            )

            HStack(spacing: 12) {
                StatTile(title: "\(viewModel.snapshot.primaryPeriodLabel) Enerji", value: NumberFormatting.kWh(viewModel.snapshot.monthlyTotalEnergy))
                StatTile(title: "\(viewModel.snapshot.primaryPeriodLabel) Seans", value: "\(viewModel.snapshot.monthlySessionCount)")
            }
            energyConsumptionModule
        }
    }

    private var betaDashboardCardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "flask")
                    .foregroundStyle(AppTheme.publicACColor)
                Text("Beta Dashboard Kartları")
                    .font(.headline)
            }

            Text("Bu alan deneysel kartlar için ayrıldı. A/B testine uygun şekilde kademeli açılabilir.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var energyConsumptionModule: some View {
        Group {
            if let value = viewModel.snapshot.averageEnergyPer100Km {
                StatTile(
                    title: "Geçmiş Ort. Tüketim",
                    value: NumberFormatting.kWhPer100Km(value.value),
                    footnote: value.isEstimated ? "Tahmini hesaplama" : nil
                )
            } else {
                EmptyInfoCard(
                    title: "Henüz yeterli veri yok",
                    subtitle: "En az 2 kayıt gerekli"
                )
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aylik Harcama Trendi (Son 12 Ay)")
                .font(.headline)

            if viewModel.snapshot.trend.isEmpty {
                Text("Trend icin yeterli veri yok")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(viewModel.snapshot.trend) { point in
                    let isSelected = selectedTrendPointID == point.id
                    BarMark(
                        x: .value("Ay", point.date, unit: .month),
                        y: .value("Tutar", point.spend)
                    )
                    .foregroundStyle(isSelected ? AppTheme.publicDCColor : AppTheme.publicACColor)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if isSelected {
                            Text(NumberFormatting.currency(point.spend, code: viewModel.snapshot.currencyCode))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppTheme.heroBackground)
                                )
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        selectTrendPoint(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }
                .frame(height: 180)
                .onTapGesture {
                    viewModel.trackChartInteraction()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Son Sarjlar")
                .font(.headline)

            if viewModel.snapshot.recentSessions.isEmpty {
                Text("Kayit yok. Ilk seansini ekledikten sonra burada gorunecek.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.snapshot.recentSessions) { session in
                    ChargingSessionRowCard(session: session, compact: true)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var noVehicleState: some View {
        EmptyStateView(
            title: "Başlamak için araç ekle",
            subtitle: "Ayarlar > Araç Yönetimi ekranından bir aracı aktif seçtiğinde Dashboard metrikleri otomatik hesaplanır.",
            iconName: "car.fill"
        )
        .frame(maxWidth: .infinity)
    }

    private var noSessionsState: some View {
        EmptyStateView(
            title: "Henüz şarj kaydı yok",
            subtitle: "İlk şarjını ekleyerek EV maliyetini hesaplamaya başla.",
            iconName: "bolt.fill",
            actionTitle: "İlk şarjı ekle",
            onAction: onAddChargeRequested
        )
        .frame(maxWidth: .infinity)
    }

    private func selectTrendPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.size.width,
              let selectedDate: Date = proxy.value(atX: relativeX) else { return }

        if let nearest = viewModel.snapshot.trend.min(by: { lhs, rhs in
            abs(lhs.date.timeIntervalSince(selectedDate)) < abs(rhs.date.timeIntervalSince(selectedDate))
        }) {
            if selectedTrendPointID != nearest.id {
                selectedTrendPointID = nearest.id
                viewModel.trackChartInteraction()
            }
        }
    }

    private func evaluateBackupBannerVisibility() {
        backupBannerCoordinator.evaluate(
            sessionState: sessionState,
            totalSessionCount: viewModel.totalSessionCount
        )
    }

    private func handleBannerDismissed() {
        backupBannerCoordinator.dismiss()
    }

    private func handleCreateAccountTapped() {
        backupBannerCoordinator.dismiss()
        onCreateAccountRequested()
    }

}
