import SwiftUI

public struct InsightsScreen: View {
    private struct SuggestedChargeSheet: Identifiable {
        let id = UUID()
        let viewModel: AddChargeViewModel
    }

    @StateObject private var viewModel: InsightsViewModel
    @State private var suggestedChargeSheet: SuggestedChargeSheet?
    @State private var selectedPersonalRecord: PersonalRecordItem?
    @State private var showDetailedInsights = false

    public init(viewModel: InsightsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !viewModel.hasActiveVehicle {
                        EmptyStateView(
                            title: "Analiz için aktif araç gerekli",
                            subtitle: "Ayarlar > Araç Yönetimi ekranından aktif aracı seç.",
                            iconName: "car.fill"
                        )
                    } else if viewModel.totalSessionCount == 0 {
                        EmptyStateView(
                            title: "Henüz analiz verisi yok",
                            subtitle: "İlk birkaç şarjdan sonra maliyet, alışkanlık ve istasyon analizlerin burada görünür.",
                            iconName: "chart.bar.doc.horizontal"
                        )
                    } else {
                        if viewModel.smartRecommendationsEnabled {
                            retentionPromptSection
                            monthlyPlanSection
                            weeklyRecommendationSection
                            dailyInsightSection
                        }
                        if viewModel.advancedInsightsEnabled {
                            userChargingProfileSection
                        }
                        if viewModel.smartRecommendationsEnabled {
                            experimentSuggestionSection
                            trendBreakSection
                        }
                        if viewModel.advancedInsightsEnabled {
                            chargeHabitSection
                            chargeHabitMetricsSection
                        }
                        consumptionSection
                        if viewModel.smartRecommendationsEnabled {
                            smartChargeSuggestionSection
                        }
                        if viewModel.advancedInsightsEnabled {
                            stationIntelligenceSection
                        }
                        goalsSection
                        if viewModel.advancedInsightsEnabled {
                            personalRecordsSection
                            detailedInsightsToggleSection
                            if showDetailedInsights {
                                detailedInsightsSection
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.insights)
            .toolbar {
                ToolbarItem(placement: .voltlyPrimaryAction) {
                    NavigationLink {
                        RealEVCostScreen(viewModel: viewModel.makeRealEVCostViewModel())
                    } label: {
                        Image(systemName: "gauge.with.needle")
                    }
                    .accessibilityLabel(L10n.realEVCost)
                }
            }
            .onAppear {
                viewModel.load()
                viewModel.refreshDailyInsightOnAppear()
            }
            .onReceive(NotificationCenter.default.publisher(for: .voltlyDataDidChange)) { _ in
                viewModel.load()
                viewModel.refreshDailyInsightOnAppear()
            }
            .sheet(item: $suggestedChargeSheet) { sheet in
                NavigationStack {
                    AddChargeScreen(
                        viewModel: sheet.viewModel,
                        onSaved: {
                            suggestedChargeSheet = nil
                            viewModel.load()
                        },
                        onShowAnalysis: nil
                    )
                }
            }
            .sheet(item: $selectedPersonalRecord) { item in
                NavigationStack {
                    PersonalRecordDetailScreen(item: item)
                        .toolbar {
                            ToolbarItem(placement: .voltlyPrimaryAction) {
                                Button("Kapat") {
                                    selectedPersonalRecord = nil
                                }
                            }
                        }
                }
            }
        }
    }

    private var tlPerKWhTrendSection: some View {
        TLPerKWhTrendCard(
            points: viewModel.tlPerKWhTrend,
            currencyCode: viewModel.tlPerKWhTrendCurrencyCode
        )
    }

    private var monthlyEVCostTrendSection: some View {
        MonthlyEVCostTrendCard(
            points: viewModel.monthlyEVCostTrend,
            currencyCode: viewModel.monthlyEVCostCurrencyCode
        )
    }

    private var advancedAnalysisSection: some View {
        AdvancedChargeAnalysisCard(report: viewModel.advancedAnalysis)
    }

    @ViewBuilder
    private var personalRecordsSection: some View {
        if !viewModel.personalRecords.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Rekorların")
                    .font(.headline)

                ForEach(viewModel.personalRecords) { item in
                    PersonalRecordCard(item: item) {
                        Haptics.softImpact()
                        selectedPersonalRecord = item
                    }
                }
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bu Ayki Hedefler")
                .font(.headline)

            if let snapshot = viewModel.goalProgressSnapshot,
               !snapshot.items.isEmpty {
                ForEach(snapshot.items) { item in
                    GoalProgressCard(item: item)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Henüz hedef tanımlanmadı")
                        .font(.subheadline.weight(.semibold))
                    Text("Ayarlar ekranından aylık harcama, DC oranı veya kayıt düzeni hedefi ekleyebilirsin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(UIConstants.cardInnerPadding)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
            }
        }
    }

    @ViewBuilder
    private var monthlyPlanSection: some View {
        if let plan = viewModel.monthlyPlan, !plan.actions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.headline)
                        Text(plan.summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    confidencePill(plan.confidence)
                }

                ForEach(plan.actions.prefix(3)) { action in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(action.isCompleted ? AppTheme.homeColor : AppTheme.publicACColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.title)
                                .font(.subheadline.weight(.semibold))
                            Text(action.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 8) {
                    Text("İlerleme %\(Int((plan.progress.fraction * 100).rounded()))")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    if let expectedSavings = plan.expectedSavings, expectedSavings > 0 {
                        Text("Beklenen etki \(NumberFormatting.currency(expectedSavings, code: viewModel.advancedAnalysis?.currencyCode ?? AppConstants.defaultCurrencyCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: plan.progress.fraction, total: 1)
                    .tint(AppTheme.publicACColor)

                if let recommendation = viewModel.primaryBehaviorRecommendation,
                   recommendation.ctaType == .addCharge {
                    Button("Planı uygula") {
                        openPrimaryRecommendation()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(recommendation.suggestedChargeType?.uiColor ?? AppTheme.publicACColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UIConstants.cardInnerPadding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        }
    }

    @ViewBuilder
    private var weeklyRecommendationSection: some View {
        if let recommendation = viewModel.primaryBehaviorRecommendation {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: recommendationIcon(recommendation))
                        .foregroundStyle(recommendation.suggestedChargeType?.uiColor ?? AppTheme.publicACColor)
                        .frame(width: 18, height: 18)
                        .padding(8)
                        .background((recommendation.suggestedChargeType?.uiColor ?? AppTheme.publicACColor).opacity(0.14))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bu haftaki öneri")
                            .font(.headline)
                        Text(recommendation.title)
                            .font(.subheadline.weight(.semibold))
                        Text(recommendation.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    confidencePill(recommendation.confidence)
                }

                if let impactText = recommendation.impactText {
                    Text(impactText)
                        .font(.caption.weight(.semibold))
                }

                if !viewModel.supportingBehaviorRecommendations.isEmpty {
                    Divider()
                    ForEach(viewModel.supportingBehaviorRecommendations, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button(recommendationCTA(recommendation)) {
                    handleBehaviorRecommendation(recommendation)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UIConstants.cardInnerPadding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        }
    }

    @ViewBuilder
    private var retentionPromptSection: some View {
        if let prompt = viewModel.retentionPrompt {
            RetentionPromptBanner(prompt: prompt)
        }
    }

    @ViewBuilder
    private var dailyInsightSection: some View {
        DailyInsightBanner(
            text: viewModel.dailyInsight?.text ?? "Bugün için öne çıkan yeni bir değişim yok.",
            isPlaceholder: viewModel.dailyInsight == nil
        )
    }

    @ViewBuilder
    private var trendBreakSection: some View {
        if let trendBreakInsight = viewModel.trendBreakInsight {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: trendBreakIcon(for: trendBreakInsight.type))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(trendBreakColor(for: trendBreakInsight.type))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Trend kırılımı")
                        .font(.subheadline.weight(.semibold))
                    Text(trendBreakInsight.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("%\(Int(trendBreakInsight.percentageChange.rounded()))")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(trendBreakColor(for: trendBreakInsight.type).opacity(0.14))
                    .foregroundStyle(trendBreakColor(for: trendBreakInsight.type))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UIConstants.cardInnerPadding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Trend kırılımı: \(trendBreakInsight.message)")
        }
    }

    @ViewBuilder
    private var contextInsightsSection: some View {
        if !viewModel.contextInsights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Bağlam Analizi")
                    .font(.headline)

                ForEach(viewModel.contextInsights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.iconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.publicACColor)
                            .frame(width: 18, height: 18)
                            .padding(8)
                            .background(AppTheme.publicACColor.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.subheadline.weight(.semibold))
                            Text(insight.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    if insight.id != viewModel.contextInsights.last?.id {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UIConstants.cardInnerPadding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        }
    }

    private func trendBreakIcon(for type: TrendBreakType) -> String {
        switch type {
        case .costIncrease:
            return "chart.line.uptrend.xyaxis.circle.fill"
        case .dcIncrease:
            return "bolt.fill"
        case .efficiencyDrop:
            return "gauge.with.needle"
        case .expensiveNewStation:
            return "mappin.and.ellipse"
        case .energyChange:
            return "bolt.circle"
        case .durationChange:
            return "clock.arrow.2.circlepath"
        case .rangeChange:
            return "arrow.left.and.right.circle"
        }
    }

    private func trendBreakColor(for type: TrendBreakType) -> Color {
        switch type {
        case .costIncrease:
            return AppTheme.publicDCColor
        case .dcIncrease:
            return AppTheme.publicDCColor
        case .efficiencyDrop:
            return AppTheme.homeColor
        case .expensiveNewStation:
            return AppTheme.publicDCColor
        case .energyChange:
            return AppTheme.homeColor
        case .durationChange:
            return AppTheme.publicACColor
        case .rangeChange:
            return AppTheme.homeColor
        }
    }

    @ViewBuilder
    private var recentSessionScoresSection: some View {
        if !viewModel.recentSessionScores.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(ChargeSessionScoringText.recentSectionTitle)
                    .font(.headline)

                ForEach(viewModel.recentSessionScores) { report in
                    ChargeSessionScoreSummaryView(report: report)
                    if report.id != viewModel.recentSessionScores.last?.id {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UIConstants.cardInnerPadding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        }
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Home / AC / DC Dağılımı")
                .font(.headline)

            MethodDistributionBar(shares: viewModel.methodShares)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    @ViewBuilder
    private var userChargingProfileSection: some View {
        if let profile = viewModel.userChargingProfile {
            UserChargingProfileCard(profile: profile)
        }
    }

    @ViewBuilder
    private var experimentSuggestionSection: some View {
        if let report = viewModel.experimentSuggestionReport {
            ExperimentSuggestionCard(
                suggestion: report.suggestion,
                onApplySuggestion: { suggestedType in
                    openSuggestedChargeSheet(with: suggestedType)
                }
            )

            if let result = report.resultInsight {
                ExperimentResultCard(result: result)
            }
        }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Davranış İçgörüleri")
                .font(.headline)

            if viewModel.insightCards.isEmpty {
                Text("Bu ay öne çıkan ek içgörü oluşmadı.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.insightCards) { insight in
                    InsightCardRow(
                        title: insight.title,
                        detail: insight.detail,
                        iconName: insight.iconName,
                        accent: insight.accent?.uiColor ?? AppTheme.publicACColor
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private var consumptionSection: some View {
        VehicleEfficiencyCard(
            summary: viewModel.vehicleEfficiencySummary,
            analysisConfidence: viewModel.vehicleEfficiencyAnalysisConfidence
        )
    }

    private var chargeHabitSection: some View {
        ChargeHabitCard(
            summary: viewModel.chargeHabitSummary,
            analysisConfidence: viewModel.chargeHabitAnalysisConfidence
        ) {
            Haptics.softImpact()
            guard let chargeViewModel = viewModel.makeSuggestedChargeViewModel() else { return }
            suggestedChargeSheet = SuggestedChargeSheet(viewModel: chargeViewModel)
        }
    }

    private var chargeHabitMetricsSection: some View {
        ChargeHabitMetricsCard(summary: viewModel.chargeHabitMetricsSummary)
    }

    private var stationPriceAnalysisSection: some View {
        StationPriceAnalysisCard(
            operatorAverages: viewModel.dcOperatorAverages,
            currencyCode: viewModel.operatorAnalysisCurrencyCode
        )
    }

    private var stationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("İstasyon Maliyet Sıralaması")
                .font(.headline)

            if viewModel.stationAverages.isEmpty {
                Text("İstasyon bazlı maliyet analizi için enerji verisi gerekli.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("En ucuz → En pahalı")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(viewModel.stationAverages.enumerated()), id: \.element.id) { index, station in
                    stationRankingRow(station: station, isBest: index == 0)
                    if index < viewModel.stationAverages.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private func stationRankingRow(station: StationAverage, isBest: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(station.station)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isBest {
                        Text("En avantajlı")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.homeColor.opacity(0.18))
                            .foregroundStyle(AppTheme.homeColor)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text("\(station.sessionCount) seans")
                    Text("•")
                    Text("Ort. hız: \(station.averageSpeedKW.map { "\(NumberFormatting.oneDecimal($0)) kW" } ?? "Veri yok")")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(NumberFormatting.tlPerKWh(station.averageTLPerKWh, currencyCode: viewModel.operatorAnalysisCurrencyCode))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isBest ? AppTheme.homeColor : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 2)
    }

    private var costAnalysisSection: some View {
        CostAnalysisCard(analysis: viewModel.costAnalysis)
    }

    @ViewBuilder
    private var smartChargeSuggestionSection: some View {
        if let suggestion = viewModel.smartChargeSuggestion {
            SmartChargeSuggestionCard(suggestion: suggestion)
        }
    }

    private func smartFavoriteDetail(for suggestion: SmartFavoriteStationSuggestion) -> String {
        switch suggestion.category {
        case .mostUsed:
            return "\(suggestion.sessionCount) seansla en sık kullandığın istasyon."
        case .cheapest:
            if let averageTLPerKWh = suggestion.averageTLPerKWh {
                return "Ortalama \(NumberFormatting.tlPerKWh(averageTLPerKWh, currencyCode: viewModel.operatorAnalysisCurrencyCode))."
            }
            return "Maliyet karşılaştırması için öne çıkıyor."
        case .mostEfficient:
            if let averageTLPer100Km = suggestion.averageTLPer100Km {
                return "Yaklaşık \(NumberFormatting.currency(averageTLPer100Km, code: viewModel.operatorAnalysisCurrencyCode)) / 100 km."
            }
            if let averageEnergyPer100Km = suggestion.averageEnergyPer100Km {
                return "Yaklaşık \(NumberFormatting.oneDecimal(averageEnergyPer100Km)) kWh / 100 km."
            }
            return "Verim tarafında öne çıkıyor."
        }
    }

    private func smartFavoriteTint(for category: SmartFavoriteStationCategory) -> Color {
        switch category {
        case .mostUsed:
            return AppTheme.publicACColor
        case .cheapest:
            return AppTheme.homeColor
        case .mostEfficient:
            return AppTheme.publicDCColor
        }
    }

    private func smartFavoriteIcon(for category: SmartFavoriteStationCategory) -> String {
        switch category {
        case .mostUsed:
            return "clock.badge.checkmark"
        case .cheapest:
            return "banknote"
        case .mostEfficient:
            return "leaf"
        }
    }

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sıcaklık Etkisi")
                .font(.headline)

            Text(viewModel.temperatureInsight ?? "Sıcaklık etkisi için yeterli veri yok.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private var fullChargeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tam Dolum Davranışı")
                .font(.headline)

            Text("Bu ay %\(Int(viewModel.fullChargeRate.rounded())) seans 100% Şarj Yüzdesi ile tamamlandı.")
                .font(.subheadline)

            if viewModel.fullChargeRate > 60 {
                Text("Uzun yol odaklı kullanım belirgin. Rutin günlerde 80-90 bandı batarya sağlığı için daha dengeli olabilir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UIConstants.cardInnerPadding)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    @ViewBuilder
    private var stationIntelligenceSection: some View {
        let report = viewModel.smartFavoriteStationReport
        let smartSuggestions = report?.suggestions ?? []
        let hasSmartSuggestions = !smartSuggestions.isEmpty
        let hasRecommendations = !viewModel.recommendations.isEmpty

        if hasSmartSuggestions || hasRecommendations {
            VStack(alignment: .leading, spacing: 10) {
                Text("İstasyon İçgörüleri")
                    .font(.headline)

                if hasSmartSuggestions {
                    ForEach(smartSuggestions.prefix(2)) { suggestion in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: smartFavoriteIcon(for: suggestion.category))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(smartFavoriteTint(for: suggestion.category))
                                .frame(width: 18, height: 18)
                                .padding(8)
                                .background(smartFavoriteTint(for: suggestion.category).opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.category.titleTR)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(smartFavoriteTint(for: suggestion.category))
                                Text(suggestion.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(smartFavoriteDetail(for: suggestion))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button {
                                    Haptics.softImpact()
                                    openSuggestedChargeSheet(with: suggestion)
                                } label: {
                                    Text("Bu istasyonla şarj ekle")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(smartFavoriteTint(for: suggestion.category).opacity(0.14))
                                        .foregroundStyle(smartFavoriteTint(for: suggestion.category))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer(minLength: 0)
                        }
                        if suggestion.id != smartSuggestions.prefix(2).last?.id || hasRecommendations {
                            Divider()
                        }
                    }
                }

                if hasRecommendations {
                    ForEach(viewModel.recommendations.prefix(2)) { recommendation in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recommendation.title)
                                .font(.subheadline.weight(.semibold))
                            Text(recommendation.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if recommendation.id != viewModel.recommendations.prefix(2).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UIConstants.cardInnerPadding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        }
    }

    private var detailedInsightsToggleSection: some View {
        Button {
            Haptics.softImpact()
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetailedInsights.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(showDetailedInsights ? "Detaylı analizleri gizle" : "Detaylı analizleri göster")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Grafikler, sıcaklık etkisi ve ham analiz kartları")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: showDetailedInsights ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.publicACColor)
                    .padding(8)
                    .background(AppTheme.publicACColor.opacity(0.14))
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UIConstants.cardInnerPadding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showDetailedInsights ? "Detaylı analizleri gizle" : "Detaylı analizleri göster")
    }

    private var detailedInsightsSection: some View {
        VStack(spacing: 12) {
            contextInsightsSection
            recentSessionScoresSection
            insightSection
            tlPerKWhTrendSection
            monthlyEVCostTrendSection
            stationPriceAnalysisSection
            stationSection
            costAnalysisSection
            temperatureSection
            fullChargeSection
            splitSection
            advancedAnalysisSection
        }
    }

    private func openSuggestedChargeSheet(with suggestedType: SuggestedChargeDefaultType) {
        let chargeViewModel = viewModel.makeSuggestedChargeViewModel(defaultChargeType: suggestedType)
        suggestedChargeSheet = SuggestedChargeSheet(viewModel: chargeViewModel)
    }

    private func openSuggestedChargeSheet(with stationSuggestion: SmartFavoriteStationSuggestion) {
        let chargeViewModel = viewModel.makeSuggestedChargeViewModel(stationSuggestion: stationSuggestion)
        suggestedChargeSheet = SuggestedChargeSheet(viewModel: chargeViewModel)
    }

    private func openPrimaryRecommendation() {
        guard let recommendation = viewModel.primaryBehaviorRecommendation else { return }
        handleBehaviorRecommendation(recommendation)
    }

    private func handleBehaviorRecommendation(_ recommendation: Recommendation) {
        switch recommendation.ctaType {
        case .addCharge:
            if let method = recommendation.suggestedChargeType {
                openSuggestedChargeSheet(with: suggestedChargeType(for: method))
            }
        case .acceptGoal, .openGoals, .openDetails:
            showDetailedInsights = true
        }
    }

    private func suggestedChargeType(for method: ChargeMethod) -> SuggestedChargeDefaultType {
        switch method {
        case .home:
            return .home
        case .publicAC:
            return .ac
        case .publicDC:
            return .dc
        }
    }

    private func recommendationCTA(_ recommendation: Recommendation) -> String {
        switch recommendation.ctaType {
        case .addCharge:
            return "Şarj ekleyerek ilerlet"
        case .acceptGoal:
            return "Hedefi incele"
        case .openGoals, .openDetails:
            return "Ayrıntıyı gör"
        }
    }

    private func recommendationIcon(_ recommendation: Recommendation) -> String {
        switch recommendation.ctaType {
        case .addCharge:
            return "sparkles"
        case .acceptGoal:
            return "target"
        case .openGoals:
            return "chart.line.uptrend.xyaxis"
        case .openDetails:
            return "info.circle"
        }
    }

    private func confidencePill(_ confidence: RecommendationConfidence) -> some View {
        Text(confidence.titleTR)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppTheme.publicACColor.opacity(0.14))
            .foregroundStyle(AppTheme.publicACColor)
            .clipShape(Capsule())
    }
}
