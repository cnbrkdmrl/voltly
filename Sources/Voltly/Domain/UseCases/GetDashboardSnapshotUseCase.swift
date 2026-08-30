import Foundation

public struct GetDashboardSnapshotUseCase {
    private static let trendMonthLimit = 12

    private struct DisplaySummarySelection {
        let label: String
        let summary: SavingsSummary?
    }

    private let vehicleRepository: VehicleRepository
    private let sessionRepository: ChargingSessionRepository
    private let settingsRepository: SettingsRepository
    private let savingsCalculationEngine: SavingsCalculationEngine
    private let vehicleMetricSnapshotRepository: (any VehicleMetricSnapshotRepository)?
    private let dashboardCacheService: (any DashboardCacheService)?

    public init(
        vehicleRepository: VehicleRepository,
        sessionRepository: ChargingSessionRepository,
        settingsRepository: SettingsRepository,
        savingsCalculationEngine: SavingsCalculationEngine = .init(),
        vehicleMetricSnapshotRepository: (any VehicleMetricSnapshotRepository)? = nil,
        dashboardCacheService: (any DashboardCacheService)? = nil
    ) {
        self.vehicleRepository = vehicleRepository
        self.sessionRepository = sessionRepository
        self.settingsRepository = settingsRepository
        self.savingsCalculationEngine = savingsCalculationEngine
        self.vehicleMetricSnapshotRepository = vehicleMetricSnapshotRepository
        self.dashboardCacheService = dashboardCacheService
    }

    public func execute(referenceDate: Date = .now) throws -> DashboardSnapshot {
        let activeVehicle = try vehicleRepository.fetchActiveVehicle()
        guard let vehicle = activeVehicle else {
            return DashboardSnapshot(
                tlPer100Km: nil,
                averageEnergyPer100Km: nil,
                currencyCode: AppConstants.defaultCurrencyCode,
                primaryPeriodLabel: "Bu Ay",
                monthlyTotalCost: 0,
                monthlyTotalEnergy: 0,
                monthlySessionCount: 0,
                totalSavingsAmount: nil,
                totalSavingsPercent: nil,
                gasolineSavingsPercent: nil,
                gasolineSavingsAmount: nil,
                calculationExplanation: nil,
                trend: [],
                recentSessions: [],
                breakdown: []
            )
        }

        let monthStart = referenceDate.startOfMonth
        let monthEnd = referenceDate.endOfMonth
        let monthlySessions = try sessionRepository.fetchInRange(vehicleID: vehicle.id, from: monthStart, to: monthEnd)
        let recent = try sessionRepository.fetchRecent(vehicleID: vehicle.id, limit: 5)
        let allSessions = try sessionRepository.fetchAll(vehicleID: vehicle.id)
        let baseline = try settingsRepository.getFuelBaseline()
        let report = savingsCalculationEngine.calculate(
            vehicle: vehicle,
            sessions: allSessions,
            preferences: baseline,
            referenceDate: referenceDate
        )
        let displaySummary = selectDisplaySummary(from: report)
        let last12Summary = report.last12Months
        let allTimeSummary = report.allTime

        let cachedSnapshots = try resolveMetricSnapshots(vehicleID: vehicle.id)
        let monthMetricSnapshot = cachedSnapshots[.last30Days]
        let yearMetricSnapshot = cachedSnapshots[.last365Days]
        let allTimeMetricSnapshot = cachedSnapshots[.allTime]

        let tlPer100: MeasuredValue<Double>?
        if (displaySummary.summary?.sessionCount ?? 0) > 0, let evCostPer100 = displaySummary.summary?.evCostPer100Km {
            if displaySummary.summary?.calculationMode.distance == .odometer,
               displaySummary.summary?.calculationMode.consumption == .realData {
                tlPer100 = .exact(evCostPer100)
            } else {
                tlPer100 = .estimated(evCostPer100)
            }
        } else if let evCostPer100 = monthMetricSnapshot?.avgTRY100Km {
            let confidence = monthMetricSnapshot?.basisLabel == ConsumptionBlockConfidenceType.real.basisLabel
                ? MeasuredValue<Double>.exact(evCostPer100)
                : MeasuredValue<Double>.estimated(evCostPer100)
            tlPer100 = confidence
        } else {
            tlPer100 = nil
        }

        let averageEnergyPer100Km: MeasuredValue<Double>?
        if ((last12Summary?.sessionCount ?? 0) > 0 || (allTimeSummary?.sessionCount ?? 0) > 0),
           let candidate = (last12Summary?.avgConsumptionKWh100km ?? allTimeSummary?.avgConsumptionKWh100km) {
            let source = last12Summary?.calculationMode.consumption ?? allTimeSummary?.calculationMode.consumption
            if source == .realData {
                averageEnergyPer100Km = .exact(candidate)
            } else {
                averageEnergyPer100Km = .estimated(candidate)
            }
        } else if let candidate = yearMetricSnapshot?.avgKWh100Km ?? allTimeMetricSnapshot?.avgKWh100Km {
            let sourceLabel = yearMetricSnapshot?.basisLabel ?? allTimeMetricSnapshot?.basisLabel
            averageEnergyPer100Km = sourceLabel == ConsumptionBlockConfidenceType.real.basisLabel
                ? .exact(candidate)
                : .estimated(candidate)
        } else {
            averageEnergyPer100Km = nil
        }

        let monthlyTotalCost = displaySummary.summary?.totalEvCost ?? 0
        let monthlyTotalEnergy = displaySummary.summary?.totalEnergyKWh ?? 0

        let trend = Array(Dictionary(grouping: allSessions) { session in
            session.sessionDate.startOfMonth
        }
        .map { key, value in
            MonthlyTrendPoint(date: key, spend: value.reduce(0) { $0 + $1.priceTotal })
        }
        .sorted { $0.date < $1.date }
        .suffix(Self.trendMonthLimit))

        let breakdown = ChargeMethod.allCases.map { method in
            let methodSessions = monthlySessions.filter { $0.chargeMethod == method }
            return CostBreakdown(
                method: method,
                totalCost: methodSessions.reduce(0) { $0 + $1.priceTotal },
                totalEnergy: methodSessions.reduce(0) { $0 + ($1.energyKWh ?? 0) },
                sessionCount: methodSessions.count
            )
        }

        return DashboardSnapshot(
            tlPer100Km: tlPer100,
            averageEnergyPer100Km: averageEnergyPer100Km,
            currencyCode: baseline.currencyCode,
            primaryPeriodLabel: displaySummary.label,
            monthlyTotalCost: monthlyTotalCost,
            monthlyTotalEnergy: monthlyTotalEnergy,
            monthlySessionCount: displaySummary.summary?.sessionCount ?? monthlySessions.count,
            totalSavingsAmount: allTimeSummary?.savingsAmount,
            totalSavingsPercent: allTimeSummary?.savingsPercent,
            gasolineSavingsPercent: displaySummary.summary?.savingsPercent,
            gasolineSavingsAmount: displaySummary.summary?.savingsAmount,
            calculationExplanation: (displaySummary.summary?.sessionCount ?? 0) > 0
                ? displaySummary.summary?.explanationText
                : monthMetricSnapshot?.basisLabel,
            trend: trend,
            recentSessions: recent,
            breakdown: breakdown
        )
    }

    private func selectDisplaySummary(
        from report: SavingsCalculationReport
    ) -> DisplaySummarySelection {
        if let thisMonth = report.thisMonth, thisMonth.sessionCount > 0 {
            return DisplaySummarySelection(label: "Bu Ay", summary: thisMonth)
        }
        if let last30 = report.last30Days, last30.sessionCount > 0 {
            return DisplaySummarySelection(label: "Son 30 Gün", summary: last30)
        }
        if let last12 = report.last12Months, last12.sessionCount > 0 {
            return DisplaySummarySelection(label: "Son 1 Yıl", summary: last12)
        }
        if let allTime = report.allTime, allTime.sessionCount > 0 {
            return DisplaySummarySelection(label: "Tüm Zamanlar", summary: allTime)
        }
        return DisplaySummarySelection(label: "Bu Ay", summary: report.thisMonth)
    }

    private func resolveMetricSnapshots(
        vehicleID: UUID
    ) throws -> [VehicleMetricSnapshotPeriod: VehicleMetricSnapshot] {
        if let cached = try dashboardCacheService?.fetch(vehicleID: vehicleID) {
            return cached.snapshots
        }

        let snapshots = try vehicleMetricSnapshotRepository?.fetchAll(vehicleID: vehicleID) ?? []
        return Dictionary(uniqueKeysWithValues: snapshots.map { ($0.period, $0) })
    }
}
