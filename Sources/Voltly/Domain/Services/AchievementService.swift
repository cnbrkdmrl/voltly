import Foundation

public enum AchievementBadgeCategory: String, Equatable, Sendable {
    case milestone
    case behavior

    public var titleTR: String {
        switch self {
        case .milestone:
            return "Kilometre taşı"
        case .behavior:
            return "Davranış"
        }
    }
}

public struct AchievementBadge: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let detail: String
    public let iconName: String
    public let isUnlocked: Bool
    public let progress: Double
    public let progressLabel: String
    public let category: AchievementBadgeCategory

    public init(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        iconName: String,
        isUnlocked: Bool,
        progress: Double,
        progressLabel: String,
        category: AchievementBadgeCategory
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.iconName = iconName
        self.isUnlocked = isUnlocked
        self.progress = progress
        self.progressLabel = progressLabel
        self.category = category
    }
}

public struct AchievementEvaluation: Equatable, Sendable {
    public let badges: [AchievementBadge]
    public let unlockedBadgeIDs: Set<String>
    public let newlyUnlockedBadges: [AchievementBadge]

    public init(
        badges: [AchievementBadge],
        unlockedBadgeIDs: Set<String>,
        newlyUnlockedBadges: [AchievementBadge]
    ) {
        self.badges = badges
        self.unlockedBadgeIDs = unlockedBadgeIDs
        self.newlyUnlockedBadges = newlyUnlockedBadges
    }
}

public struct AchievementService {
    private enum Thresholds {
        static let firstChargeCount = 1
        static let tenChargeCount = 10
        static let fiftyChargeCount = 50
        static let thousandKWh = 1_000.0
        static let regularTrackerWindowDays = 60
        static let regularTrackerSessionCount = 12
        static let consistentTrackingWindowDays = 14
        static let consistentTrackingSessionCount = 4
        static let dcControlWindowDays = 7
        static let dcControlMaxRatio = 35.0
        static let efficientWindowTargetCount = 5
        static let improvementThreshold = 10.0
    }

    public init() {}

    public func evaluate(
        sessions: [ChargingSession],
        previouslyUnlockedIDs: Set<String>,
        referenceDate: Date = .now
    ) -> AchievementEvaluation {
        let totalSessionCount = sessions.count
        let totalEnergyKWh = sessions.reduce(0) { partial, session in
            partial + max(0, session.energyKWh ?? 0)
        }
        let recentSessionCount = sessionsInPastDays(
            sessions,
            days: Thresholds.regularTrackerWindowDays,
            endingAt: referenceDate
        ).count
        let consistentTrackingCount = sessionsInPastDays(
            sessions,
            days: Thresholds.consistentTrackingWindowDays,
            endingAt: referenceDate
        ).count
        let dcControlProgress = dcControlProgress(
            sessions: sessions,
            referenceDate: referenceDate
        )
        let efficientWindowCount = sessions.filter(isEfficientWindowSession).count
        let acHomeImprovement = acHomeImprovement(from: sessions, referenceDate: referenceDate)
        let costDropImprovement = costDropImprovement(from: sessions, referenceDate: referenceDate)

        let hasHomeSession = sessions.contains { $0.chargeMethod == .home }
        let hasACSession = sessions.contains { $0.chargeMethod == .publicAC }
        let hasDCSession = sessions.contains { $0.chargeMethod == .publicDC }

        let badges: [AchievementBadge] = [
            countBadge(
                id: "first_charge",
                title: "İlk şarj",
                subtitle: "İlk şarj kaydını tamamla",
                detail: "İlk kayıt davranış analizlerini başlatır.",
                iconName: "sparkles",
                current: totalSessionCount,
                target: Thresholds.firstChargeCount,
                category: .milestone
            ),
            countBadge(
                id: "ten_charges",
                title: "10 şarj",
                subtitle: "Toplam 10 şarj kaydı oluştur",
                detail: "Daha güçlü trend ve maliyet analizi için temel eşik.",
                iconName: "bolt.circle",
                current: totalSessionCount,
                target: Thresholds.tenChargeCount,
                category: .milestone
            ),
            countBadge(
                id: "fifty_charges",
                title: "50 şarj",
                subtitle: "Toplam 50 şarj kaydına ulaş",
                detail: "Uzun dönem alışkanlık modelini netleştirir.",
                iconName: "bolt.circle.fill",
                current: totalSessionCount,
                target: Thresholds.fiftyChargeCount,
                category: .milestone
            ),
            valueBadge(
                id: "thousand_kwh",
                title: "1000 kWh toplam",
                subtitle: "Toplam şarj enerjisinde 1000 kWh seviyesine ulaş",
                detail: "Uzun dönem tüketim profilini anlamlı hale getirir.",
                iconName: "battery.100.bolt",
                current: totalEnergyKWh,
                target: Thresholds.thousandKWh,
                unitSuffix: "kWh",
                category: .milestone
            ),
            binaryBadge(
                id: "first_home_charge",
                title: "İlk ev şarjı",
                subtitle: "Ev şarjında ilk kaydını oluştur",
                detail: "Ev şarjı maliyet istikrarı için önemli bir referans oluşturur.",
                iconName: "house.fill",
                isUnlocked: hasHomeSession,
                category: .milestone
            ),
            binaryBadge(
                id: "first_ac_charge",
                title: "İlk AC",
                subtitle: "AC şarj yönteminde ilk kaydını oluştur",
                detail: "AC maliyet karşılaştırmaları için ilk gerçek örneği ekler.",
                iconName: "bolt",
                isUnlocked: hasACSession,
                category: .milestone
            ),
            binaryBadge(
                id: "first_dc_charge",
                title: "İlk DC",
                subtitle: "DC şarj yönteminde ilk kaydını oluştur",
                detail: "Hız odaklı seansların maliyet etkisini ölçmeye başlar.",
                iconName: "bolt.fill",
                isUnlocked: hasDCSession,
                category: .milestone
            ),
            countBadge(
                id: "regular_tracker",
                title: "Düzenli takipçi",
                subtitle: "Son 60 günde en az 12 şarj kaydı oluştur",
                detail: "Düzenli kayıt, öneri motorunun güvenini artırır.",
                iconName: "calendar.badge.clock",
                current: recentSessionCount,
                target: Thresholds.regularTrackerSessionCount,
                category: .milestone
            ),
            countBadge(
                id: "consistent_tracking",
                title: "2 hafta düzenli kayıt",
                subtitle: "Son 14 günde en az 4 kayıt oluştur",
                detail: "Kısa dönem plan ilerlemesini güvenilir hale getirir.",
                iconName: "calendar.badge.checkmark",
                current: consistentTrackingCount,
                target: Thresholds.consistentTrackingSessionCount,
                category: .behavior
            ),
            ratioBadge(
                id: "dc_control_week",
                title: "DC hedefinin altında",
                subtitle: "Son 7 günde DC payını düşük tut",
                detail: "Hızlı şarjı sınırlı tutmak maliyeti daha dengeli hale getirir.",
                iconName: "bolt.slash.fill",
                current: dcControlProgress.currentValue,
                target: dcControlProgress.targetValue,
                isUnlocked: dcControlProgress.isUnlocked
            ),
            countBadge(
                id: "efficient_window",
                title: "Verimli pencere",
                subtitle: "5 seansı sağlıklı şarj aralığında tut",
                detail: "%20-%80 benzeri dengeli pencere, verim yorumlarını güçlendirir.",
                iconName: "battery.75",
                current: efficientWindowCount,
                target: Thresholds.efficientWindowTargetCount,
                category: .behavior
            ),
            ratioBadge(
                id: "ac_home_improver",
                title: "AC/Ev ağırlığını iyileştirdin",
                subtitle: "Son dönemde AC/Ev payını artır",
                detail: "AC ve ev payındaki artış genelde daha öngörülebilir maliyet üretir.",
                iconName: "leaf.arrow.circlepath",
                current: acHomeImprovement.currentValue,
                target: Thresholds.improvementThreshold,
                isUnlocked: acHomeImprovement.isUnlocked
            ),
            ratioBadge(
                id: "cost_drop",
                title: "Maliyet düşüşü",
                subtitle: "Son dönemde birim maliyeti aşağı çek",
                detail: "Daha iyi yöntem dağılımı ve istasyon seçimiyle toplam maliyet düşebilir.",
                iconName: "chart.line.downtrend.xyaxis",
                current: costDropImprovement.currentValue,
                target: Thresholds.improvementThreshold,
                isUnlocked: costDropImprovement.isUnlocked
            )
        ]

        let unlockedBadgeIDs = Set(badges.filter(\.isUnlocked).map(\.id))
        let newlyUnlocked = badges.filter { badge in
            badge.isUnlocked && !previouslyUnlockedIDs.contains(badge.id)
        }

        return AchievementEvaluation(
            badges: badges,
            unlockedBadgeIDs: unlockedBadgeIDs,
            newlyUnlockedBadges: newlyUnlocked
        )
    }

    private func countBadge(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        iconName: String,
        current: Int,
        target: Int,
        category: AchievementBadgeCategory
    ) -> AchievementBadge {
        let boundedCurrent = max(0, current)
        let boundedTarget = max(1, target)
        let progress = min(1, max(0, Double(boundedCurrent) / Double(boundedTarget)))
        let isUnlocked = boundedCurrent >= boundedTarget
        let progressLabel = isUnlocked
            ? "Kazanıldı"
            : "\(boundedCurrent)/\(boundedTarget)"

        return AchievementBadge(
            id: id,
            title: title,
            subtitle: subtitle,
            detail: detail,
            iconName: iconName,
            isUnlocked: isUnlocked,
            progress: progress,
            progressLabel: progressLabel,
            category: category
        )
    }

    private func valueBadge(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        iconName: String,
        current: Double,
        target: Double,
        unitSuffix: String,
        category: AchievementBadgeCategory
    ) -> AchievementBadge {
        let boundedCurrent = max(0, current)
        let boundedTarget = max(1, target)
        let progress = min(1, max(0, boundedCurrent / boundedTarget))
        let isUnlocked = boundedCurrent >= boundedTarget
        let progressLabel = isUnlocked
            ? "Kazanıldı"
            : "\(Int(boundedCurrent.rounded())) / \(Int(boundedTarget.rounded())) \(unitSuffix)"

        return AchievementBadge(
            id: id,
            title: title,
            subtitle: subtitle,
            detail: detail,
            iconName: iconName,
            isUnlocked: isUnlocked,
            progress: progress,
            progressLabel: progressLabel,
            category: category
        )
    }

    private func binaryBadge(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        iconName: String,
        isUnlocked: Bool,
        category: AchievementBadgeCategory
    ) -> AchievementBadge {
        AchievementBadge(
            id: id,
            title: title,
            subtitle: subtitle,
            detail: detail,
            iconName: iconName,
            isUnlocked: isUnlocked,
            progress: isUnlocked ? 1 : 0,
            progressLabel: isUnlocked ? "Kazanıldı" : "0/1",
            category: category
        )
    }

    private func ratioBadge(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        iconName: String,
        current: Double,
        target: Double,
        isUnlocked: Bool
    ) -> AchievementBadge {
        let boundedTarget = max(1, target)
        let boundedCurrent = max(0, current)
        let progress = min(1, boundedCurrent / boundedTarget)
        let label = isUnlocked
            ? "Kazanıldı"
            : "%\(Int(boundedCurrent.rounded())) / %\(Int(boundedTarget.rounded()))"

        return AchievementBadge(
            id: id,
            title: title,
            subtitle: subtitle,
            detail: detail,
            iconName: iconName,
            isUnlocked: isUnlocked,
            progress: progress,
            progressLabel: label,
            category: .behavior
        )
    }

    private func dcControlProgress(
        sessions: [ChargingSession],
        referenceDate: Date
    ) -> (currentValue: Double, targetValue: Double, isUnlocked: Bool) {
        let recent = sessionsInPastDays(
            sessions,
            days: Thresholds.dcControlWindowDays,
            endingAt: referenceDate
        )
        guard !recent.isEmpty else {
            return (0, Thresholds.dcControlMaxRatio, false)
        }
        let dcCount = recent.filter { $0.chargeMethod == .publicDC }.count
        let ratio = (Double(dcCount) / Double(recent.count)) * 100
        return (
            currentValue: max(0, Thresholds.dcControlMaxRatio - ratio),
            targetValue: Thresholds.dcControlMaxRatio,
            isUnlocked: recent.count >= 3 && ratio <= Thresholds.dcControlMaxRatio
        )
    }

    private func acHomeImprovement(
        from sessions: [ChargingSession],
        referenceDate: Date
    ) -> (currentValue: Double, isUnlocked: Bool) {
        let recent = sessionsInPastDays(sessions, days: 30, endingAt: referenceDate)
        let previous = sessionsInPreviousWindow(sessions, days: 30, referenceDate: referenceDate)
        let recentRatio = acHomeRatio(in: recent)
        let previousRatio = acHomeRatio(in: previous)
        let delta = max(0, recentRatio - previousRatio)
        return (delta, recent.count >= 3 && previous.count >= 3 && delta >= Thresholds.improvementThreshold)
    }

    private func costDropImprovement(
        from sessions: [ChargingSession],
        referenceDate: Date
    ) -> (currentValue: Double, isUnlocked: Bool) {
        let recent = sessionsInPastDays(sessions, days: 30, endingAt: referenceDate)
        let previous = sessionsInPreviousWindow(sessions, days: 30, referenceDate: referenceDate)
        guard let recentAverage = averageTLPerKWh(in: recent),
              let previousAverage = averageTLPerKWh(in: previous),
              previousAverage > 0 else {
            return (0, false)
        }
        let improvement = max(0, ((previousAverage - recentAverage) / previousAverage) * 100)
        return (improvement, recent.count >= 3 && previous.count >= 3 && improvement >= Thresholds.improvementThreshold)
    }

    private func acHomeRatio(in sessions: [ChargingSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let count = sessions.filter { $0.chargeMethod == .home || $0.chargeMethod == .publicAC }.count
        return (Double(count) / Double(sessions.count)) * 100
    }

    private func averageTLPerKWh(in sessions: [ChargingSession]) -> Double? {
        let priced = sessions.compactMap { session -> Double? in
            guard let energy = session.energyKWh, energy > 0 else { return nil }
            return session.priceTotal / energy
        }
        guard !priced.isEmpty else { return nil }
        return priced.reduce(0, +) / Double(priced.count)
    }

    private func isEfficientWindowSession(_ session: ChargingSession) -> Bool {
        session.socStart >= 15 && session.socStart <= 30 && session.socEnd >= 70 && session.socEnd <= 85
    }

    private func sessionsInPastDays(
        _ sessions: [ChargingSession],
        days: Int,
        endingAt referenceDate: Date
    ) -> [ChargingSession] {
        let calendar = Calendar.current
        let start = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? calendar.startOfDay(for: referenceDate)

        return sessions.filter { $0.sessionDate >= start && $0.sessionDate <= referenceDate }
    }

    private func sessionsInPreviousWindow(
        _ sessions: [ChargingSession],
        days: Int,
        referenceDate: Date
    ) -> [ChargingSession] {
        let calendar = Calendar.current
        let currentWindowStart = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? calendar.startOfDay(for: referenceDate)
        let previousWindowEnd = currentWindowStart.addingTimeInterval(-1)
        let previousWindowStart = calendar.date(
            byAdding: .day,
            value: -days,
            to: currentWindowStart
        ) ?? currentWindowStart

        return sessions.filter { $0.sessionDate >= previousWindowStart && $0.sessionDate <= previousWindowEnd }
    }
}
