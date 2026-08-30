import Foundation

public enum UserChargingProfileType: String, CaseIterable, Equatable {
    case speedFocused
    case savingsFocused
    case balanced
    case homeHeavy
    case acHeavy
    case dcHeavy

    public var titleTR: String {
        switch self {
        case .speedFocused:
            return "Hız odaklı"
        case .savingsFocused:
            return "Tasarruf odaklı"
        case .balanced:
            return "Dengeli kullanıcı"
        case .homeHeavy:
            return "Ev ağırlıklı"
        case .acHeavy:
            return "AC ağırlıklı"
        case .dcHeavy:
            return "DC ağırlıklı"
        }
    }

    public var iconName: String {
        switch self {
        case .speedFocused:
            return "bolt.badge.clock.fill"
        case .savingsFocused:
            return "leaf.fill"
        case .balanced:
            return "scale.3d"
        case .homeHeavy:
            return "house.fill"
        case .acHeavy:
            return "bolt"
        case .dcHeavy:
            return "bolt.fill"
        }
    }

    public var accentMethod: ChargeMethod {
        switch self {
        case .speedFocused, .dcHeavy:
            return .publicDC
        case .savingsFocused, .homeHeavy:
            return .home
        case .acHeavy, .balanced:
            return .publicAC
        }
    }
}

public struct UserChargingProfileReport: Equatable {
    public let type: UserChargingProfileType
    public let headline: String
    public let description: String
    public let ratioSummary: String
    public let confidence: DataConfidenceScore
    public let sessionCount: Int
    public let generatedAt: Date

    public init(
        type: UserChargingProfileType,
        headline: String,
        description: String,
        ratioSummary: String,
        confidence: DataConfidenceScore,
        sessionCount: Int,
        generatedAt: Date
    ) {
        self.type = type
        self.headline = headline
        self.description = description
        self.ratioSummary = ratioSummary
        self.confidence = confidence
        self.sessionCount = sessionCount
        self.generatedAt = generatedAt
    }
}

public struct UserChargingProfileService {
    private enum Constants {
        static let minimumRequiredSessions = 6

        static let speedFocusedDCThreshold = 65.0
        static let speedFocusedDurationMinutesMax = 55.0

        static let savingsFocusedCombinedHomeACThreshold = 78.0
        static let savingsFocusedDCThreshold = 22.0

        static let heavyHomeThreshold = 55.0
        static let heavyACThreshold = 55.0
        static let heavyDCThreshold = 55.0

        static let balancedHomeRange = 20.0...45.0
        static let balancedACRange = 25.0...50.0
        static let balancedDCRange = 15.0...35.0
    }

    public init() {}

    public func makeProfile(
        report: ChargeInsightReport,
        referenceDate: Date = .now
    ) -> UserChargingProfileReport? {
        guard report.overall.sessionCount >= Constants.minimumRequiredSessions else {
            return nil
        }

        guard let homeRatio = report.usageRatios.homeRatio.value,
              let acRatio = report.usageRatios.acRatio.value,
              let dcRatio = report.usageRatios.dcRatio.value else {
            return nil
        }

        let averageDurationMinutes = report.overall.averageDurationMinutes.value
        let profileType = classify(
            homeRatio: homeRatio,
            acRatio: acRatio,
            dcRatio: dcRatio,
            averageDurationMinutes: averageDurationMinutes
        )
        let confidence = mergeConfidence([
            report.usageRatios.homeRatio.confidence,
            report.usageRatios.acRatio.confidence,
            report.usageRatios.dcRatio.confidence,
            report.overall.averageDurationMinutes.confidence
        ])

        return UserChargingProfileReport(
            type: profileType,
            headline: profileType.titleTR,
            description: description(
                for: profileType,
                homeRatio: homeRatio,
                acRatio: acRatio,
                dcRatio: dcRatio
            ),
            ratioSummary: ratioSummary(homeRatio: homeRatio, acRatio: acRatio, dcRatio: dcRatio),
            confidence: confidence,
            sessionCount: report.overall.sessionCount,
            generatedAt: referenceDate
        )
    }

    private func classify(
        homeRatio: Double,
        acRatio: Double,
        dcRatio: Double,
        averageDurationMinutes: Double?
    ) -> UserChargingProfileType {
        if dcRatio >= Constants.speedFocusedDCThreshold,
           let averageDurationMinutes,
           averageDurationMinutes <= Constants.speedFocusedDurationMinutesMax {
            return .speedFocused
        }

        if (homeRatio + acRatio) >= Constants.savingsFocusedCombinedHomeACThreshold,
           dcRatio <= Constants.savingsFocusedDCThreshold {
            return .savingsFocused
        }

        if homeRatio >= Constants.heavyHomeThreshold {
            return .homeHeavy
        }

        if acRatio >= Constants.heavyACThreshold {
            return .acHeavy
        }

        if dcRatio >= Constants.heavyDCThreshold {
            return .dcHeavy
        }

        if Constants.balancedHomeRange.contains(homeRatio),
           Constants.balancedACRange.contains(acRatio),
           Constants.balancedDCRange.contains(dcRatio) {
            return .balanced
        }

        let dominant = [
            (type: UserChargingProfileType.homeHeavy, ratio: homeRatio),
            (type: UserChargingProfileType.acHeavy, ratio: acRatio),
            (type: UserChargingProfileType.dcHeavy, ratio: dcRatio)
        ]
            .max(by: { $0.ratio < $1.ratio })?
            .type

        return dominant ?? .balanced
    }

    private func description(
        for type: UserChargingProfileType,
        homeRatio: Double,
        acRatio: Double,
        dcRatio: Double
    ) -> String {
        switch type {
        case .speedFocused:
            return "DC kullanımın yüksek, hız odaklı görünüyorsun. Hız kazanımı sağlarken maliyeti dengelemek için AC seanslarını artırabilirsin."
        case .savingsFocused:
            return "AC ve ev şarjı ağırlığın tasarruf potansiyelini artırıyor. Bu düzen birim maliyeti daha stabil tutar."
        case .balanced:
            return "Ev, AC ve DC dağılımın dengeli. Hız ve maliyet tarafını kontrollü şekilde yönetiyorsun."
        case .homeHeavy:
            return "Şarjlarının çoğunu evde yapıyorsun. Bu tercih maliyet istikrarı ve planlı kullanım için güçlü bir temel oluşturur."
        case .acHeavy:
            return "AC kullanımın baskın. Maliyet odaklı ilerliyorsun, ihtiyaç oldukça DC ile destekleyerek dengeyi koruyabilirsin."
        case .dcHeavy:
            if dcRatio >= (homeRatio + acRatio) {
                return "DC kullanımın yüksek. Hız avantajın güçlü ama toplam maliyeti sınırlamak için AC/Ev oranını artırmayı düşünebilirsin."
            }
            return "DC kullanımın öne çıkıyor. Kısa süreli ihtiyaçlar için iyi, ancak maliyet dengesi için AC tarafını biraz güçlendirmek faydalı olur."
        }
    }

    private func ratioSummary(
        homeRatio: Double,
        acRatio: Double,
        dcRatio: Double
    ) -> String {
        "Ev %\(Int(homeRatio.rounded())) • AC %\(Int(acRatio.rounded())) • DC %\(Int(dcRatio.rounded()))"
    }

    private func mergeConfidence(_ scores: [DataConfidenceScore]) -> DataConfidenceScore {
        let validScores = scores.filter { $0.source != .unavailable }
        guard !validScores.isEmpty else {
            return .unavailable
        }

        let averageScore = Int(
            (Double(validScores.map(\.score).reduce(0, +)) / Double(validScores.count)).rounded()
        )
        let source: AnalysisDataSourceKind
        let sources = validScores.map(\.source)
        if sources.allSatisfy({ $0 == .real }) {
            source = .real
        } else if sources.allSatisfy({ $0 == .estimated }) {
            source = .estimated
        } else {
            source = .mixed
        }

        return DataConfidenceScore(
            score: averageScore,
            source: source,
            sampleCount: validScores.map(\.sampleCount).max() ?? 0,
            exactSampleCount: validScores.map(\.exactSampleCount).max() ?? 0,
            estimatedSampleCount: validScores.map(\.estimatedSampleCount).max() ?? 0,
            missingSampleCount: validScores.map(\.missingSampleCount).max() ?? 0
        )
    }
}
