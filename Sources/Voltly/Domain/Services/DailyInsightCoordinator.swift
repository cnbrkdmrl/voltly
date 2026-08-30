import Foundation

@MainActor
public final class DailyInsightCoordinator {
    private enum PersistenceKeys {
        static let lastShownInsightID = "daily_insight.last_shown.id"
        static let lastShownAt = "daily_insight.last_shown.at"
    }

    private enum Constants {
        static let suppressionInterval: TimeInterval = 24 * 60 * 60
        static let weeklyWindowDays = 7
        static let savingsWindowDays = 30
    }

    private let vehicleRepository: any VehicleRepository
    private let chargingSessionRepository: any ChargingSessionRepository
    private let settingsRepository: any SettingsRepository
    private let skill: GenerateDailyInsightSkill
    private let estimateDrivingDistanceUseCase = EstimateDrivingDistanceUseCase()
    private let userDefaults: UserDefaults

    private var cachedInsight: DailyInsightOutput?
    private var sessionDeliveredInsightID: String?

    public init(
        vehicleRepository: any VehicleRepository,
        chargingSessionRepository: any ChargingSessionRepository,
        settingsRepository: any SettingsRepository,
        skill: GenerateDailyInsightSkill = .init(),
        userDefaults: UserDefaults = .standard
    ) {
        self.vehicleRepository = vehicleRepository
        self.chargingSessionRepository = chargingSessionRepository
        self.settingsRepository = settingsRepository
        self.skill = skill
        self.userDefaults = userDefaults
    }

    public func refreshCandidate(referenceDate: Date = .now) {
        cachedInsight = makeCandidate(referenceDate: referenceDate)
    }

    public func consumeDisplayableInsight(referenceDate: Date = .now) -> DailyInsightOutput? {
        let candidate = cachedInsight ?? makeCandidate(referenceDate: referenceDate)
        guard let candidate else { return nil }
        guard !isSuppressed(candidate, referenceDate: referenceDate) ||
                sessionDeliveredInsightID == candidate.id else {
            return nil
        }

        cachedInsight = candidate
        if sessionDeliveredInsightID != candidate.id {
            markShown(candidate, referenceDate: referenceDate)
            sessionDeliveredInsightID = candidate.id
        }
        return candidate
    }

    public func clearCachedInsight() {
        cachedInsight = nil
        sessionDeliveredInsightID = nil
    }

    private func makeCandidate(referenceDate: Date) -> DailyInsightOutput? {
        do {
            guard let vehicle = try vehicleRepository.fetchActiveVehicle() else { return nil }
            let sessions = try chargingSessionRepository.fetchAll(vehicleID: vehicle.id)
            guard !sessions.isEmpty else { return nil }

            let input = GenerateDailyInsightInput(
                lastSessions: sessions,
                trendData: DailyInsightTrendData(
                    savingsDelta: try savingsDelta(
                        vehicle: vehicle,
                        sessions: sessions,
                        referenceDate: referenceDate
                    ),
                    averageChargeRangeDelta: averageChargeRangeDelta(
                        sessions: sessions,
                        referenceDate: referenceDate
                    )
                ),
                usageStats: DailyInsightUsageStats(
                    currentWeekDCRatio: dcUsageRatio(
                        inPastDays: Constants.weeklyWindowDays,
                        sessions: sessions,
                        referenceDate: referenceDate
                    ),
                    previousWeekDCRatio: dcUsageRatio(
                        inPreviousDays: Constants.weeklyWindowDays,
                        sessions: sessions,
                        referenceDate: referenceDate
                    )
                ),
                stationStats: primaryStationStats(from: sessions)
            )

            return skill.generate(input: input)
        } catch {
            return nil
        }
    }

    private func savingsDelta(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        referenceDate: Date
    ) throws -> Double? {
        let baseline = try settingsRepository.getFuelBaseline()
        let currentWindow = sessionsInPastDays(
            Constants.savingsWindowDays,
            sessions: sessions,
            referenceDate: referenceDate
        )
        let previousWindow = sessionsInPreviousDays(
            Constants.savingsWindowDays,
            sessions: sessions,
            referenceDate: referenceDate
        )

        guard !currentWindow.isEmpty, !previousWindow.isEmpty else { return nil }

        let currentSavings = calculateSavings(
            vehicle: vehicle,
            sessions: currentWindow,
            baseline: baseline
        )
        let previousSavings = calculateSavings(
            vehicle: vehicle,
            sessions: previousWindow,
            baseline: baseline
        )

        return currentSavings - previousSavings
    }

    private func calculateSavings(
        vehicle: Vehicle,
        sessions: [ChargingSession],
        baseline: FuelBaselineSettings
    ) -> Double {
        let evSpend = sessions.reduce(0) { $0 + $1.priceTotal }
        let distance = estimateDrivingDistanceUseCase.execute(sessions: sessions, vehicle: vehicle)
        let gasolineCost = (distance / 100) * baseline.fuelPricePerLiter * baseline.iceConsumptionLPer100Km
        return max(0, gasolineCost - evSpend)
    }

    private func dcUsageRatio(
        inPastDays days: Int,
        sessions: [ChargingSession],
        referenceDate: Date
    ) -> Double? {
        let window = sessionsInPastDays(days, sessions: sessions, referenceDate: referenceDate)
        return dcUsageRatio(for: window)
    }

    private func dcUsageRatio(
        inPreviousDays days: Int,
        sessions: [ChargingSession],
        referenceDate: Date
    ) -> Double? {
        let window = sessionsInPreviousDays(days, sessions: sessions, referenceDate: referenceDate)
        return dcUsageRatio(for: window)
    }

    private func dcUsageRatio(for sessions: [ChargingSession]) -> Double? {
        guard !sessions.isEmpty else { return nil }
        let dcCount = sessions.filter { $0.chargeMethod == .publicDC }.count
        return (Double(dcCount) / Double(sessions.count)) * 100
    }

    private func averageChargeRangeDelta(
        sessions: [ChargingSession],
        referenceDate: Date
    ) -> Double? {
        let currentWindow = sessionsInPastDays(
            Constants.savingsWindowDays,
            sessions: sessions,
            referenceDate: referenceDate
        )
        let previousWindow = sessionsInPreviousDays(
            Constants.savingsWindowDays,
            sessions: sessions,
            referenceDate: referenceDate
        )

        guard let currentAverage = averageChargeRange(for: currentWindow),
              let previousAverage = averageChargeRange(for: previousWindow) else {
            return nil
        }

        return currentAverage - previousAverage
    }

    private func averageChargeRange(for sessions: [ChargingSession]) -> Double? {
        let values = sessions.compactMap { session -> Double? in
            guard session.socEnd > session.socStart else { return nil }
            return session.socEnd - session.socStart
        }

        guard values.count >= 2 else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func primaryStationStats(
        from sessions: [ChargingSession]
    ) -> DailyInsightStationStats? {
        let stationSessions = sessions.compactMap { session -> (String, Double)? in
            guard session.chargeMethod != .home,
                  let tlPerKWh = session.tlPerKWh else {
                return nil
            }

            let name = session.stationDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name != "Konum yok" else { return nil }
            return (name, tlPerKWh)
        }

        guard !stationSessions.isEmpty else { return nil }

        let overallAverage = stationSessions.map(\.1).reduce(0, +) / Double(stationSessions.count)
        guard let entry = Dictionary(grouping: stationSessions, by: \.0).max(by: { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                return lhs.key > rhs.key
            }
            return lhs.value.count < rhs.value.count
        }) else {
            return nil
        }

        let stationAverage = entry.value.map(\.1).reduce(0, +) / Double(entry.value.count)

        return DailyInsightStationStats(
            stationName: entry.key,
            averageTLPerKWh: stationAverage,
            overallAverageTLPerKWh: overallAverage,
            sessionCount: entry.value.count
        )
    }

    private func sessionsInPastDays(
        _ days: Int,
        sessions: [ChargingSession],
        referenceDate: Date
    ) -> [ChargingSession] {
        let calendar = Calendar.current
        let start = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? calendar.startOfDay(for: referenceDate)

        return sessions.filter { $0.sessionDate >= start && $0.sessionDate <= referenceDate }
    }

    private func sessionsInPreviousDays(
        _ days: Int,
        sessions: [ChargingSession],
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

        return sessions.filter {
            $0.sessionDate >= previousWindowStart && $0.sessionDate <= previousWindowEnd
        }
    }

    private func isSuppressed(
        _ candidate: DailyInsightOutput,
        referenceDate: Date
    ) -> Bool {
        guard let lastShownID = userDefaults.string(forKey: PersistenceKeys.lastShownInsightID),
              let lastShownAt = userDefaults.object(forKey: PersistenceKeys.lastShownAt) as? Date else {
            return false
        }

        guard lastShownID == candidate.id else { return false }
        return referenceDate.timeIntervalSince(lastShownAt) < Constants.suppressionInterval
    }

    private func markShown(
        _ candidate: DailyInsightOutput,
        referenceDate: Date
    ) {
        userDefaults.set(candidate.id, forKey: PersistenceKeys.lastShownInsightID)
        userDefaults.set(referenceDate, forKey: PersistenceKeys.lastShownAt)
    }
}
