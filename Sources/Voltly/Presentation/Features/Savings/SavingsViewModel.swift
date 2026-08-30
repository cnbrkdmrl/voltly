import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

@MainActor
public final class SavingsViewModel: ObservableObject {
    @Published public private(set) var hasActiveVehicle = false
    @Published public private(set) var totalSessionCount = 0
    @Published public private(set) var vehicleName = "EV"
    @Published public private(set) var primaryPeriodTitle = "Bu ay"

    @Published public private(set) var monthlySavingsTL: Double = 0
    @Published public private(set) var allTimeSavingsTL: Double = 0
    @Published public private(set) var monthlyEVSpendTL: Double = 0
    @Published public private(set) var monthlyGasolineTL: Double = 0
    @Published public private(set) var monthlyEnergyKWh: Double = 0
    @Published public private(set) var monthlySessionCount: Int = 0
    @Published public private(set) var monthlyDistanceKM: Double = 0
    @Published public private(set) var monthlyCO2AvoidedKG: Double = 0
    @Published public private(set) var allTimeCO2AvoidedKG: Double = 0
    @Published public private(set) var allTimeTreeEquivalent: Int = 0
    @Published public private(set) var tlPer100Km: MeasuredValue<Double>?
    @Published public private(set) var gasolineSavingsPercent: Double?
    @Published public private(set) var gasolineComparisonText: String = "Benzin karşılaştırması için veri yok."
    @Published public private(set) var calculationExplanation: String = ""
    @Published public private(set) var equivalentItems: [SavingsEquivalentItem] = []
    @Published public private(set) var currencyCode: String = AppConstants.defaultCurrencyCode
    @Published public private(set) var savingsBankV2Enabled = false
    @Published public private(set) var activePlan: MonthlyPlan?
    @Published public private(set) var planImpactHeadline: String?
    @Published public private(set) var planImpactDetail: String?
    @Published public private(set) var availableShareVariants: [SavingsShareCardVariant] = [.monthlySavings]
    @Published public private(set) var shareCardContent = SavingsShareCardContent(
        variant: .monthlySavings,
        badgeTitle: "Bu Ay Tasarruf",
        headline: "₺0",
        supportingText: "Veri geldikçe kart güncellenecek.",
        vehicleName: "EV",
        metrics: [],
        highlightText: "İlk birkaç kayıt sonrası karşılaştırma netleşir.",
        footerText: "Şarjını Voltly ile akıllı takip et"
    )

    @Published public var selectedShareVariant: SavingsShareCardVariant = .monthlySavings {
        didSet {
            guard availableShareVariants.contains(selectedShareVariant) else {
                selectedShareVariant = availableShareVariants.first ?? .monthlySavings
                return
            }
            updateShareContent()
            #if os(iOS)
            renderShareCard()
            #endif
        }
    }

    @Published public private(set) var shareCopy: String = ""

    #if os(iOS)
    @Published public private(set) var shareImage: UIImage?
    #endif

    private let environment: AppEnvironment
    private var monthlyDCRatio: Double?
    private var chargeInsightReport: ChargeInsightReport?
    private var goals: [UserGoal] = []

    private struct DisplaySummarySelection {
        let title: String
        let summary: SavingsSummary?
    }

    public init(environment: AppEnvironment) {
        self.environment = environment
        refreshFeatureFlags()
    }

    public func load(referenceDate: Date = .now) {
        do {
            refreshFeatureFlags()
            guard let vehicle = try environment.vehicleRepository.fetchActiveVehicle() else {
                hasActiveVehicle = false
                monthlySavingsTL = 0
                allTimeSavingsTL = 0
                monthlyEVSpendTL = 0
                monthlyGasolineTL = 0
                monthlyEnergyKWh = 0
                monthlySessionCount = 0
                monthlyDistanceKM = 0
                monthlyCO2AvoidedKG = 0
                allTimeCO2AvoidedKG = 0
                allTimeTreeEquivalent = 0
                equivalentItems = []
                gasolineSavingsPercent = nil
                gasolineComparisonText = "Benzin karşılaştırması için veri yok."
                calculationExplanation = ""
                currencyCode = AppConstants.defaultCurrencyCode
                totalSessionCount = 0
                primaryPeriodTitle = "Bu ay"
                return
            }

            hasActiveVehicle = true
            vehicleName = "\(vehicle.brand) \(vehicle.model)"

            let monthSessions = try environment.chargingSessionRepository.fetchInRange(
                vehicleID: vehicle.id,
                from: referenceDate.startOfMonth,
                to: referenceDate.endOfMonth
            )
            let allSessions = try environment.chargingSessionRepository.fetchAll(vehicleID: vehicle.id)
            totalSessionCount = allSessions.count
            let baseline = try environment.settingsRepository.getFuelBaseline()
            currencyCode = baseline.currencyCode

            let report = environment.savingsCalculationEngine.calculate(
                vehicle: vehicle,
                sessions: allSessions,
                preferences: baseline,
                referenceDate: referenceDate
            )
            let metricSnapshots = Dictionary(
                uniqueKeysWithValues: try environment.vehicleMetricSnapshotRepository
                    .fetchAll(vehicleID: vehicle.id)
                    .map { ($0.period, $0) }
            )
            let chargeInsightReport = allSessions.isEmpty
                ? nil
                : environment.chargeInsightService.analyze(
                    vehicle: vehicle,
                    sessions: allSessions,
                    referenceDate: referenceDate
                )
            let usageMode = environment.usageModeStore.loadUsageMode()
            let goals = try environment.goalRepository.fetchGoals()
            let suggestedGoals = environment.goalSuggestionEngine.suggest(
                input: GoalSuggestionInput(
                    usageMode: usageMode,
                    report: chargeInsightReport,
                    savingsReport: report,
                    sessions: allSessions,
                    referenceDate: referenceDate
                )
            )
            let confidence = environment.confidenceScoreEngine.evaluate(
                ConfidenceScoreInput(
                    sampleCount: chargeInsightReport?.overall.sessionCount ?? allSessions.count,
                    dataConfidence: chargeInsightReport?.overall.averageTLPer100Km.confidence,
                    hasCostData: report.thisMonth?.costPerKWh != nil || !allSessions.isEmpty,
                    hasDistanceData: report.thisMonth?.estimatedDistanceKm ?? 0 > 0
                )
            )
            let basePlan = environment.monthlyPlanEngine.buildPlan(
                MonthlyPlanInput(
                    usageMode: usageMode,
                    suggestedGoals: goals.isEmpty ? suggestedGoals : nil,
                    activeGoals: goals,
                    report: chargeInsightReport,
                    savingsSummary: report.thisMonth ?? report.last30Days,
                    sessions: allSessions,
                    referenceDate: referenceDate
                ),
                confidence: confidence
            )
            activePlan = environment.habitProgressEngine.evaluate(
                PlanProgressInput(
                    plan: basePlan,
                    report: chargeInsightReport,
                    savingsSummary: report.thisMonth ?? report.last30Days,
                    sessions: allSessions,
                    referenceDate: referenceDate
                )
            )
            self.chargeInsightReport = chargeInsightReport
            self.goals = goals
            monthlyDCRatio = chargeInsightReport?.usageRatios.dcRatio.value
            let displaySummary = selectDisplaySummary(from: report)
            let monthSummary = displaySummary.summary
            let allTimeSummary = report.allTime
            primaryPeriodTitle = displaySummary.title

            monthlyEVSpendTL = monthSummary?.totalEvCost ?? 0
            monthlyEnergyKWh = monthSummary?.totalEnergyKWh ?? 0
            monthlySessionCount = monthSummary?.sessionCount ?? monthSessions.count
            monthlyDistanceKM = monthSummary?.estimatedDistanceKm ?? 0
            monthlyGasolineTL = monthSummary?.gasolineEquivalentCost ?? 0
            monthlySavingsTL = monthSummary?.savingsAmount ?? 0
            allTimeSavingsTL = allTimeSummary?.savingsAmount ?? 0
            gasolineSavingsPercent = monthSummary?.savingsPercent ?? metricSnapshots[.last30Days]?.savingPercent
            gasolineComparisonText = makeGasolineComparisonText(
                savingsAmount: monthlySavingsTL,
                savingsPercent: gasolineSavingsPercent
            )
            if let monthSummary, monthSummary.sessionCount > 0 {
                calculationExplanation = monthSummary.explanationText
            } else {
                calculationExplanation = metricSnapshots[.last30Days]?.basisLabel ?? ""
            }

            if let evCostPer100 = monthSummary?.evCostPer100Km {
                if monthSummary?.calculationMode.distance == .odometer,
                   monthSummary?.calculationMode.consumption == .realData {
                    tlPer100Km = .exact(evCostPer100)
                } else {
                    tlPer100Km = .estimated(evCostPer100)
                }
            } else if let snapshotTRYPer100 = metricSnapshots[.last30Days]?.avgTRY100Km {
                let isExact = metricSnapshots[.last30Days]?.basisLabel == ConsumptionBlockConfidenceType.real.basisLabel
                tlPer100Km = isExact ? .exact(snapshotTRYPer100) : .estimated(snapshotTRYPer100)
            } else {
                tlPer100Km = nil
            }

            equivalentItems = makeEquivalentItems(
                summary: report.savingsPiggyBank,
                gasTankLiters: 50
            )
            if let activePlan, !activePlan.actions.isEmpty {
                planImpactHeadline = "Bu ay planına %\(Int((activePlan.progress.fraction * 100).rounded())) uyum gösterdin"
                if let expectedSavings = activePlan.expectedSavings, expectedSavings > 0 {
                    planImpactDetail = "Uyum devam ederse yaklaşık \(NumberFormatting.currency(expectedSavings, code: currencyCode)) ek avantaj görünür."
                } else {
                    planImpactDetail = "AC/Ev tercihini güçlendirmek tasarruf eğrisini daha dengeli tutabilir."
                }
            } else {
                planImpactHeadline = nil
                planImpactDetail = nil
            }
            monthlyCO2AvoidedKG = report.carbonSummary.monthlyAvoidedCO2Kg
            if monthlyCO2AvoidedKG == 0, primaryPeriodTitle != "Bu ay" {
                monthlyCO2AvoidedKG = (monthSummary?.estimatedDistanceKm ?? 0) * 0.12
            }
            allTimeCO2AvoidedKG = report.carbonSummary.avoidedCO2Kg
            allTimeTreeEquivalent = report.carbonSummary.equivalentTrees

            updateAvailableShareVariants()
            if !availableShareVariants.contains(selectedShareVariant) {
                selectedShareVariant = availableShareVariants.first ?? .monthlySavings
            } else {
                updateShareContent()
            }
        } catch {
            hasActiveVehicle = false
            totalSessionCount = 0
            gasolineSavingsPercent = nil
            gasolineComparisonText = "Benzin karşılaştırması için veri yok."
            calculationExplanation = ""
            primaryPeriodTitle = "Bu ay"
            monthlyCO2AvoidedKG = 0
            allTimeCO2AvoidedKG = 0
            allTimeTreeEquivalent = 0
            activePlan = nil
            planImpactHeadline = nil
            planImpactDetail = nil
            chargeInsightReport = nil
            goals = []
            monthlyDCRatio = nil
            availableShareVariants = [.monthlySavings]
            selectedShareVariant = .monthlySavings
            updateShareContent()
        }
    }

    private func refreshFeatureFlags() {
        savingsBankV2Enabled = environment.featureAccessChecker.isEnabled(.savingsBankV2)
    }

    #if os(iOS)
    public func renderShareCard() {
        let card = SavingsShareCardView(content: shareCardContent)
        .frame(width: 360, height: 640)

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        shareImage = renderer.uiImage
    }
    #endif

    private func makeGasolineComparisonText(
        savingsAmount: Double,
        savingsPercent: Double?
    ) -> String {
        guard let savingsPercent else {
            return "Benzin karsilastirmasi icin mesafe ve tuketim verisi gerekli."
        }

        let absPercent = abs(savingsPercent)
        if savingsAmount > 0 {
            return "Benzine gore \(NumberFormatting.percent(absPercent)) daha ucuz"
        }
        if savingsAmount < 0 {
            return "Benzine gore \(NumberFormatting.percent(absPercent)) daha pahali"
        }
        return "Benzin ile ayni maliyet"
    }

    private func makeEquivalentItems(
        summary: SavingsPiggyBankSummary,
        gasTankLiters: Int
    ) -> [SavingsEquivalentItem] {
        [
            SavingsEquivalentItem(
                title: "depo benzin",
                value: summary.depositsEquivalent,
                subtitle: "Yaklasik \(gasTankLiters)L dolum"
            ),
            SavingsEquivalentItem(
                title: "aylik abonelik",
                value: summary.monthlySubscriptionEquivalent,
                subtitle: "Muzik / video aboneligi seviyesinde"
            ),
            SavingsEquivalentItem(
                title: "kahve",
                value: summary.coffeeEquivalent,
                subtitle: "Ortalama zincir kahve fiyati"
            ),
            SavingsEquivalentItem(
                title: "aksam yemegi",
                value: summary.dinnerEquivalent,
                subtitle: "2 kisilik ortalama yemek maliyeti"
            )
        ]
    }

    public func selectShareVariant(_ variant: SavingsShareCardVariant) {
        selectedShareVariant = variant
    }

    private func updateAvailableShareVariants() {
        availableShareVariants = [.monthlySavings]
    }

    private func updateShareContent() {
        switch selectedShareVariant {
        case .monthlySavings:
            shareCardContent = makeMonthlySavingsShareCardContent()
        case .planSuccess:
            shareCardContent = makePlanSuccessShareCardContent()
        case .goalCompletion:
            shareCardContent = makeGoalCompletionShareCardContent()
        case .dcReduction:
            shareCardContent = makeDCReductionShareCardContent()
        case .carbonGain:
            shareCardContent = makeCarbonGainShareCardContent()
        }
        shareCopy = makeShareCopy(for: shareCardContent)
    }

    private func makeMonthlySavingsShareCardContent() -> SavingsShareCardContent {
        let compareText: String
        if let gasolineSavingsPercent {
            let absolute = abs(gasolineSavingsPercent)
            compareText = gasolineSavingsPercent >= 0
                ? "Benzine göre \(NumberFormatting.percent(absolute)) daha dengeli."
                : "Benzine göre \(NumberFormatting.percent(absolute)) daha pahalı."
        } else {
            compareText = "Benzin karşılaştırması için veri biraz daha artmalı."
        }

        return SavingsShareCardContent(
            variant: .monthlySavings,
            badgeTitle: "\(primaryPeriodTitle.capitalized) Tasarruf",
            headline: NumberFormatting.currency(monthlySavingsTL, code: currencyCode),
            supportingText: compareText,
            vehicleName: vehicleName,
            metrics: [
                SavingsShareCardMetric(id: "evCost", title: "EV Harcama", value: NumberFormatting.currency(monthlyEVSpendTL, code: currencyCode)),
                SavingsShareCardMetric(id: "tl100", title: "TL/100 km", value: tlPer100Km.map { NumberFormatting.oneDecimal($0.value) } ?? "--"),
                SavingsShareCardMetric(id: "energy", title: "Enerji", value: NumberFormatting.kWh(monthlyEnergyKWh)),
                SavingsShareCardMetric(id: "session", title: "Seans", value: "\(monthlySessionCount)")
            ],
            highlightText: gasolineComparisonText,
            footerText: "Şarjını Voltly ile akıllı takip et"
        )
    }

    private func makePlanSuccessShareCardContent() -> SavingsShareCardContent {
        let progressPercent = Int(((activePlan?.progress.fraction ?? 0) * 100).rounded())
        let expected = activePlan?.expectedSavings ?? 0

        return SavingsShareCardContent(
            variant: .planSuccess,
            badgeTitle: "Plan Başarısı",
            headline: "%\(progressPercent)",
            supportingText: activePlan?.summary ?? "Bu ay davranış planın aktif.",
            vehicleName: vehicleName,
            metrics: [
                SavingsShareCardMetric(id: "actions", title: "Aksiyon", value: "\(activePlan?.actions.count ?? 0)"),
                SavingsShareCardMetric(id: "expected", title: "Beklenen", value: NumberFormatting.currency(expected, code: currencyCode)),
                SavingsShareCardMetric(id: "saving", title: primaryPeriodTitle.capitalized, value: NumberFormatting.currency(monthlySavingsTL, code: currencyCode)),
                SavingsShareCardMetric(id: "confidence", title: "Güven", value: activePlan?.confidence.titleTR ?? "Tahmini")
            ],
            highlightText: planImpactHeadline ?? "Plan ilerlemesi yeni kayıtlarla netleşir.",
            footerText: "Voltly bu ay davranış planını takip ediyor"
        )
    }

    private func makeGoalCompletionShareCardContent() -> SavingsShareCardContent {
        let progressPercent = Int(((activePlan?.progress.fraction ?? 0) * 100).rounded())
        let headline: String
        let supporting: String

        if let firstGoal = goals.first {
            headline = firstGoal.type.titleTR
            supporting = "Bu ay hedef takibini veriyle güncel tutuyorsun."
        } else {
            headline = "%\(progressPercent)"
            supporting = "Voltly senin için hedefe yakın bir rota çizdi."
        }

        return SavingsShareCardContent(
            variant: .goalCompletion,
            badgeTitle: "Hedef İlerlemesi",
            headline: headline,
            supportingText: supporting,
            vehicleName: vehicleName,
            metrics: [
                SavingsShareCardMetric(id: "progress", title: "İlerleme", value: "%\(progressPercent)"),
                SavingsShareCardMetric(id: "session", title: "Kayıt", value: "\(monthlySessionCount)"),
                SavingsShareCardMetric(id: "savings", title: "Tasarruf", value: NumberFormatting.currency(monthlySavingsTL, code: currencyCode)),
                SavingsShareCardMetric(id: "energy", title: "Enerji", value: NumberFormatting.kWh(monthlyEnergyKWh))
            ],
            highlightText: planImpactDetail ?? "Hedefler birkaç seans daha ile daha net ölçülür.",
            footerText: "Küçük seçimler hedef çizgisini belirginleştirir"
        )
    }

    private func makeDCReductionShareCardContent() -> SavingsShareCardContent {
        let dcRatio = monthlyDCRatio ?? 0
        let dcAction = activePlan?.actions.first(where: { $0.type == .reduceDC })
        let target = dcAction?.targetValue ?? 60
        let gap = max(0, dcRatio - target)

        return SavingsShareCardContent(
            variant: .dcReduction,
            badgeTitle: "DC Azaltma Etkisi",
            headline: "%\(Int(dcRatio.rounded())) DC",
            supportingText: gap > 0
                ? "DC payını \(Int(gap.rounded())) puan dengelemek bu ay maliyeti iyileştirebilir."
                : "DC kullanımın hedef banda yakın görünüyor.",
            vehicleName: vehicleName,
            metrics: [
                SavingsShareCardMetric(id: "dc", title: "DC Oranı", value: "%\(Int(dcRatio.rounded()))"),
                SavingsShareCardMetric(id: "target", title: "Hedef", value: "%\(Int(target.rounded()))"),
                SavingsShareCardMetric(id: "saving", title: "Tasarruf", value: NumberFormatting.currency(monthlySavingsTL, code: currencyCode)),
                SavingsShareCardMetric(id: "sessions", title: "Seans", value: "\(monthlySessionCount)")
            ],
            highlightText: gap > 0
                ? "AC/Ev tarafına kaydıkça toplam maliyet daha kontrollü kalabilir."
                : "DC tercihin şu an dengeli bir bantta ilerliyor.",
            footerText: "Hız ve maliyet dengesini Voltly ile takip et"
        )
    }

    private func makeCarbonGainShareCardContent() -> SavingsShareCardContent {
        SavingsShareCardContent(
            variant: .carbonGain,
            badgeTitle: "Karbon Kazanımı",
            headline: "\(NumberFormatting.oneDecimal(allTimeCO2AvoidedKG)) kg CO2",
            supportingText: "Tahmini karbon kazanımın tüm kayıtların üzerinden hesaplandı.",
            vehicleName: vehicleName,
            metrics: [
                SavingsShareCardMetric(id: "monthly", title: primaryPeriodTitle.capitalized, value: "\(NumberFormatting.oneDecimal(monthlyCO2AvoidedKG)) kg"),
                SavingsShareCardMetric(id: "tree", title: "Ağaç", value: "\(allTimeTreeEquivalent)"),
                SavingsShareCardMetric(id: "energy", title: "Enerji", value: NumberFormatting.kWh(monthlyEnergyKWh)),
                SavingsShareCardMetric(id: "session", title: "Seans", value: "\(monthlySessionCount)")
            ],
            highlightText: "Elektrikli kullanımın görünür bir karbon farkı yaratıyor.",
            footerText: "Tasarrufun yanında etkini de görünür kıl"
        )
    }

    private func makeShareCopy(for content: SavingsShareCardContent) -> String {
        switch content.variant {
        case .monthlySavings:
            return "Voltly ile \(primaryPeriodTitle.lowercased()) \(vehicleName) kullanımımda \(NumberFormatting.currency(monthlySavingsTL, code: currencyCode)) tasarruf görünümü oluştu. \(gasolineComparisonText)."
        case .planSuccess:
            let progressPercent = Int(((activePlan?.progress.fraction ?? 0) * 100).rounded())
            return "Voltly bu ay plan takibimde %\(progressPercent) ilerleme gösteriyor. \(planImpactDetail ?? "Davranış planım aktif.")"
        case .goalCompletion:
            let progressPercent = Int(((activePlan?.progress.fraction ?? 0) * 100).rounded())
            return "Voltly hedef takibimde bu ay %\(progressPercent) görünür ilerleme yakaladığımı gösteriyor."
        case .dcReduction:
            let dcRatio = Int((monthlyDCRatio ?? 0).rounded())
            return "Voltly verilerine göre bu ay DC payım %\(dcRatio). Daha dengeli şarj dağılımı maliyeti aşağı çekebilir."
        case .carbonGain:
            return "Voltly ile elektrikli kullanımımda tahmini \(NumberFormatting.oneDecimal(allTimeCO2AvoidedKG)) kg CO2 kazanımı oluştu."
        }
    }

    private func selectDisplaySummary(
        from report: SavingsCalculationReport
    ) -> DisplaySummarySelection {
        if let thisMonth = report.thisMonth, thisMonth.sessionCount > 0 {
            return DisplaySummarySelection(title: "Bu ay", summary: thisMonth)
        }
        if let last30 = report.last30Days, last30.sessionCount > 0 {
            return DisplaySummarySelection(title: "Son 30 gün", summary: last30)
        }
        if let last12 = report.last12Months, last12.sessionCount > 0 {
            return DisplaySummarySelection(title: "Son 1 yıl", summary: last12)
        }
        if let allTime = report.allTime, allTime.sessionCount > 0 {
            return DisplaySummarySelection(title: "Tüm zamanlar", summary: allTime)
        }
        return DisplaySummarySelection(title: "Bu ay", summary: report.thisMonth)
    }
}
