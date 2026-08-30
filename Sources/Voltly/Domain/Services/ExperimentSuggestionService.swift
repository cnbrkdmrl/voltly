import Foundation

public enum ExperimentSuggestionType: String, Equatable, Sendable {
    case increaseAC
    case reduceDC
    case keepRange2080
    case evaluateHomeOpportunity

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .increaseAC:
            return "bolt.badge.plus"
        case .reduceDC:
            return "bolt.slash"
        case .keepRange2080:
            return "battery.75"
        case .evaluateHomeOpportunity:
            return "house.and.flag"
        }
    }

    public var accentMethod: ChargeMethod {
        switch self {
        case .increaseAC:
            return .publicAC
        case .reduceDC:
            return .publicDC
        case .keepRange2080:
            return .publicAC
        case .evaluateHomeOpportunity:
            return .home
        }
    }
}

public struct ExperimentSuggestion: Identifiable, Equatable, Sendable {
    public let type: ExperimentSuggestionType
    public let title: String
    public let message: String
    public let suggestedChargeType: SuggestedChargeDefaultType

    public init(
        type: ExperimentSuggestionType,
        title: String,
        message: String,
        suggestedChargeType: SuggestedChargeDefaultType
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.suggestedChargeType = suggestedChargeType
    }

    public var id: String {
        type.id
    }
}

public struct ExperimentResultInsight: Identifiable, Equatable, Sendable {
    public let id: String
    public let type: ExperimentSuggestionType
    public let title: String
    public let message: String

    public init(
        id: String,
        type: ExperimentSuggestionType,
        title: String,
        message: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
    }
}

public struct ExperimentSuggestionReport: Equatable, Sendable {
    public let suggestion: ExperimentSuggestion
    public let resultInsight: ExperimentResultInsight?

    public init(
        suggestion: ExperimentSuggestion,
        resultInsight: ExperimentResultInsight?
    ) {
        self.suggestion = suggestion
        self.resultInsight = resultInsight
    }
}

public struct ExperimentSuggestionService {
    private enum Constants {
        static let minimumRequiredSessions = 6

        static let acLowRatioThreshold = 25.0
        static let dcHighRatioThreshold = 60.0
        static let homeLowRatioThreshold = 15.0

        static let rangeTargetStart = 20.0
        static let rangeTargetEnd = 80.0
        static let rangeTolerance = 5.0
        static let wideRangeThreshold = 70.0

        static let weeklyWindowDays = 7
        static let minimumWindowSessions = 2

        static let meaningfulRatioShift = 8.0
        static let meaningfulRangeShift = 12.0
        static let meaningfulSavingsThreshold = 1.0

        static let suggestionPriorityReduceDC = 320
        static let suggestionPriorityIncreaseAC = 280
        static let suggestionPriorityRange = 240
        static let suggestionPriorityHome = 200
    }

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func makeReport(
        report: ChargeInsightReport,
        profile: UserChargingProfileReport?,
        sessions: [ChargingSession],
        referenceDate: Date = .now
    ) -> ExperimentSuggestionReport? {
        guard report.overall.sessionCount >= Constants.minimumRequiredSessions else {
            return nil
        }

        guard let suggestion = buildSuggestion(report: report, profile: profile) else {
            return nil
        }

        let resultInsight = buildResultInsight(
            for: suggestion,
            sessions: sessions,
            currencyCode: report.currencyCode,
            referenceDate: referenceDate
        )

        return ExperimentSuggestionReport(
            suggestion: suggestion,
            resultInsight: resultInsight
        )
    }

    private func buildSuggestion(
        report: ChargeInsightReport,
        profile: UserChargingProfileReport?
    ) -> ExperimentSuggestion? {
        let homeRatio = report.usageRatios.homeRatio.value ?? 0
        let acRatio = report.usageRatios.acRatio.value ?? 0
        let dcRatio = report.usageRatios.dcRatio.value ?? 0

        let averageStartSOC = report.lastThirtyDays.averageStartSOC.value ?? report.overall.averageStartSOC.value
        let averageEndSOC = report.lastThirtyDays.averageEndSOC.value ?? report.overall.averageEndSOC.value
        let averageRange: Double? = {
            guard let averageStartSOC,
                  let averageEndSOC,
                  averageEndSOC > averageStartSOC else {
                return nil
            }
            return averageEndSOC - averageStartSOC
        }()

        let profileType = profile?.type
        var candidates: [(priority: Int, suggestion: ExperimentSuggestion)] = []

        if dcRatio >= Constants.dcHighRatioThreshold ||
            profileType == .speedFocused ||
            profileType == .dcHeavy {
            let suggestedType: SuggestedChargeDefaultType = homeRatio >= acRatio && homeRatio > 0 ? .home : .ac
            let message = "DC payın %\(Int(dcRatio.rounded())) seviyesinde. Mümkün olan seanslarda \(suggestedType.chargeMethod.titleTR) ağırlığı denemek maliyeti daha dengeli tutabilir."
            candidates.append((
                Constants.suggestionPriorityReduceDC,
                ExperimentSuggestion(
                    type: .reduceDC,
                    title: "DC oranını düşürmeyi dene",
                    message: message,
                    suggestedChargeType: suggestedType
                )
            ))
        }

        if acRatio < Constants.acLowRatioThreshold || profileType == .homeHeavy {
            let message = "AC payın %\(Int(acRatio.rounded())) görünüyor. Bu hafta 2-3 seansı AC planlamak birim maliyeti sakinleştirmeye yardımcı olabilir."
            candidates.append((
                Constants.suggestionPriorityIncreaseAC,
                ExperimentSuggestion(
                    type: .increaseAC,
                    title: "Bu hafta daha fazla AC dene",
                    message: message,
                    suggestedChargeType: .ac
                )
            ))
        }

        if shouldSuggestRangeOptimization(
            averageStartSOC: averageStartSOC,
            averageEndSOC: averageEndSOC,
            averageRange: averageRange,
            profileType: profileType
        ) {
            let message: String
            if let averageStartSOC, let averageEndSOC {
                message = "Ortalama aralığın %\(Int(averageStartSOC.rounded()))-%\(Int(averageEndSOC.rounded())) bandında. Bir süre %20-%80 hedefiyle gitmek verimi düzenleyebilir."
            } else {
                message = "%20-%80 aralığını hedefleyen kısa bir deneme, süre ve maliyet dengesini iyileştirmeye yardımcı olabilir."
            }

            candidates.append((
                Constants.suggestionPriorityRange,
                ExperimentSuggestion(
                    type: .keepRange2080,
                    title: "%20-%80 aralığında kalmayı dene",
                    message: message,
                    suggestedChargeType: homeRatio > 0 ? .home : .ac
                )
            ))
        }

        if homeRatio < Constants.homeLowRatioThreshold,
           profileType != .homeHeavy {
            let message = "Ev şarjı payın %\(Int(homeRatio.rounded())) seviyesinde. Uygunluk varsa haftalık birkaç seansı evden yapmak maliyeti daha öngörülebilir hale getirebilir."
            candidates.append((
                Constants.suggestionPriorityHome,
                ExperimentSuggestion(
                    type: .evaluateHomeOpportunity,
                    title: "Ev şarjı fırsatını değerlendirebilirsin",
                    message: message,
                    suggestedChargeType: .home
                )
            ))
        }

        return candidates.max(by: { $0.priority < $1.priority })?.suggestion
    }

    private func shouldSuggestRangeOptimization(
        averageStartSOC: Double?,
        averageEndSOC: Double?,
        averageRange: Double?,
        profileType: UserChargingProfileType?
    ) -> Bool {
        if profileType == .speedFocused {
            return true
        }

        guard let averageStartSOC,
              let averageEndSOC else {
            return false
        }

        let startLowerBound = Constants.rangeTargetStart - Constants.rangeTolerance
        let startUpperBound = Constants.rangeTargetStart + Constants.rangeTolerance
        let endLowerBound = Constants.rangeTargetEnd - Constants.rangeTolerance
        let endUpperBound = Constants.rangeTargetEnd + Constants.rangeTolerance

        if averageStartSOC < startLowerBound || averageStartSOC > startUpperBound {
            return true
        }

        if averageEndSOC < endLowerBound || averageEndSOC > endUpperBound {
            return true
        }

        if let averageRange,
           averageRange > Constants.wideRangeThreshold {
            return true
        }

        return false
    }

    private func buildResultInsight(
        for suggestion: ExperimentSuggestion,
        sessions: [ChargingSession],
        currencyCode: String,
        referenceDate: Date
    ) -> ExperimentResultInsight? {
        let recentWindow = weekWindow(
            sessions: sessions,
            endingAt: referenceDate,
            weeksAgo: 0
        )
        let previousWindow = weekWindow(
            sessions: sessions,
            endingAt: referenceDate,
            weeksAgo: 1
        )

        guard recentWindow.sessionCount >= Constants.minimumWindowSessions,
              previousWindow.sessionCount >= Constants.minimumWindowSessions else {
            return nil
        }

        switch suggestion.type {
        case .increaseAC:
            return buildIncreaseACResult(
                recent: recentWindow,
                previous: previousWindow,
                currencyCode: currencyCode
            )
        case .reduceDC:
            return buildReduceDCResult(
                recent: recentWindow,
                previous: previousWindow,
                currencyCode: currencyCode
            )
        case .keepRange2080:
            return buildRangeResult(recent: recentWindow, previous: previousWindow)
        case .evaluateHomeOpportunity:
            return buildHomeResult(
                recent: recentWindow,
                previous: previousWindow,
                currencyCode: currencyCode
            )
        }
    }

    private func buildIncreaseACResult(
        recent: WeeklyStats,
        previous: WeeklyStats,
        currencyCode: String
    ) -> ExperimentResultInsight? {
        let acIncrease = recent.acRatio - previous.acRatio
        guard acIncrease >= Constants.meaningfulRatioShift else {
            return nil
        }

        if let savings = estimatedSavings(previous: previous, recent: recent),
           savings >= Constants.meaningfulSavingsThreshold {
            return ExperimentResultInsight(
                id: "experiment-result.increase-ac.savings",
                type: .increaseAC,
                title: "AC denemesi olumlu gidiyor",
                message: "Bu hafta AC ağırlığını artırarak yaklaşık \(NumberFormatting.currency(savings, code: currencyCode)) tasarruf ettin."
            )
        }

        return ExperimentResultInsight(
            id: "experiment-result.increase-ac.progress",
            type: .increaseAC,
            title: "AC denemesinde ilerleme var",
            message: "AC payın geçen haftaya göre %\(Int(acIncrease.rounded())) arttı. Birkaç seans daha ekledikçe etki netleşecek."
        )
    }

    private func buildReduceDCResult(
        recent: WeeklyStats,
        previous: WeeklyStats,
        currencyCode: String
    ) -> ExperimentResultInsight? {
        let dcDrop = previous.dcRatio - recent.dcRatio
        guard dcDrop >= Constants.meaningfulRatioShift else {
            return nil
        }

        if let savings = estimatedSavings(previous: previous, recent: recent),
           savings >= Constants.meaningfulSavingsThreshold {
            return ExperimentResultInsight(
                id: "experiment-result.reduce-dc.savings",
                type: .reduceDC,
                title: "DC dengelemesi işe yarıyor",
                message: "DC payını azaltarak bu hafta yaklaşık \(NumberFormatting.currency(savings, code: currencyCode)) avantaj yakaladın."
            )
        }

        return ExperimentResultInsight(
            id: "experiment-result.reduce-dc.progress",
            type: .reduceDC,
            title: "DC oranı daha dengeli",
            message: "DC kullanımını geçen haftaya göre %\(Int(dcDrop.rounded())) düşürdün. Bu dengeyi sürdürmek maliyeti destekleyebilir."
        )
    }

    private func buildRangeResult(
        recent: WeeklyStats,
        previous: WeeklyStats
    ) -> ExperimentResultInsight? {
        let healthyRangeGain = recent.healthyRangeRatio - previous.healthyRangeRatio
        guard healthyRangeGain >= Constants.meaningfulRangeShift else {
            return nil
        }

        return ExperimentResultInsight(
            id: "experiment-result.range.progress",
            type: .keepRange2080,
            title: "Şarj aralığı daha sağlıklı",
            message: "Bu hafta %20-%80 bandına uyumun %\(Int(healthyRangeGain.rounded())) arttı. Bu düzen verim ve süre dengesini güçlendirir."
        )
    }

    private func buildHomeResult(
        recent: WeeklyStats,
        previous: WeeklyStats,
        currencyCode: String
    ) -> ExperimentResultInsight? {
        let homeIncrease = recent.homeRatio - previous.homeRatio
        guard homeIncrease >= Constants.meaningfulRatioShift else {
            return nil
        }

        if let savings = estimatedSavings(previous: previous, recent: recent),
           savings >= Constants.meaningfulSavingsThreshold {
            return ExperimentResultInsight(
                id: "experiment-result.home.savings",
                type: .evaluateHomeOpportunity,
                title: "Ev şarjı denemesi verimli",
                message: "Ev şarjı payını artırarak bu hafta yaklaşık \(NumberFormatting.currency(savings, code: currencyCode)) tasarruf sağladın."
            )
        }

        return ExperimentResultInsight(
            id: "experiment-result.home.progress",
            type: .evaluateHomeOpportunity,
            title: "Ev şarjı payın artıyor",
            message: "Ev şarjı kullanımın geçen haftaya göre %\(Int(homeIncrease.rounded())) yükseldi. Bu eğilim maliyet stabilitesini destekler."
        )
    }

    private func weekWindow(
        sessions: [ChargingSession],
        endingAt referenceDate: Date,
        weeksAgo: Int
    ) -> WeeklyStats {
        let normalizedEnd = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(
            byAdding: .day,
            value: -(weeksAgo * Constants.weeklyWindowDays),
            to: normalizedEnd
        ) ?? normalizedEnd
        let start = calendar.date(
            byAdding: .day,
            value: -(Constants.weeklyWindowDays - 1),
            to: end
        ) ?? end

        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let windowSessions = sessions.filter {
            $0.sessionDate >= start && $0.sessionDate < nextDayStart
        }

        return makeWeeklyStats(from: windowSessions)
    }

    private func makeWeeklyStats(from sessions: [ChargingSession]) -> WeeklyStats {
        guard !sessions.isEmpty else {
            return WeeklyStats.empty
        }

        let totalEnergy = sessions.reduce(0.0) { partial, session in
            partial + max(session.energyKWh ?? 0, 0)
        }
        let totalCost = sessions.reduce(0.0) { $0 + $1.priceTotal }
        let homeCount = sessions.filter { $0.chargeMethod == .home }.count
        let acCount = sessions.filter { $0.chargeMethod == .publicAC }.count
        let dcCount = sessions.filter { $0.chargeMethod == .publicDC }.count

        let healthyRangeCount = sessions.filter { session in
            let startInBand = session.socStart >= (Constants.rangeTargetStart - Constants.rangeTolerance) &&
                session.socStart <= (Constants.rangeTargetStart + Constants.rangeTolerance)
            let endInBand = session.socEnd >= (Constants.rangeTargetEnd - Constants.rangeTolerance) &&
                session.socEnd <= (Constants.rangeTargetEnd + Constants.rangeTolerance)
            return endInBand && startInBand && session.socEnd > session.socStart
        }.count

        return WeeklyStats(
            sessionCount: sessions.count,
            totalEnergy: totalEnergy,
            averageTLPerKWh: totalEnergy > 0 ? (totalCost / totalEnergy) : nil,
            homeRatio: ratio(count: homeCount, totalCount: sessions.count),
            acRatio: ratio(count: acCount, totalCount: sessions.count),
            dcRatio: ratio(count: dcCount, totalCount: sessions.count),
            healthyRangeRatio: ratio(count: healthyRangeCount, totalCount: sessions.count)
        )
    }

    private func ratio(count: Int, totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return (Double(count) / Double(totalCount)) * 100
    }

    private func estimatedSavings(
        previous: WeeklyStats,
        recent: WeeklyStats
    ) -> Double? {
        guard let previousTLPerKWh = previous.averageTLPerKWh,
              let recentTLPerKWh = recent.averageTLPerKWh,
              previousTLPerKWh > recentTLPerKWh,
              recent.totalEnergy > 0 else {
            return nil
        }

        return (previousTLPerKWh - recentTLPerKWh) * recent.totalEnergy
    }

    private struct WeeklyStats {
        let sessionCount: Int
        let totalEnergy: Double
        let averageTLPerKWh: Double?
        let homeRatio: Double
        let acRatio: Double
        let dcRatio: Double
        let healthyRangeRatio: Double

        static let empty = WeeklyStats(
            sessionCount: 0,
            totalEnergy: 0,
            averageTLPerKWh: nil,
            homeRatio: 0,
            acRatio: 0,
            dcRatio: 0,
            healthyRangeRatio: 0
        )
    }
}
