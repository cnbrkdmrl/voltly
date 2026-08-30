import Foundation

public struct MonthlyTrendPoint: Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    public let spend: Double

    public init(id: UUID = UUID(), date: Date, spend: Double) {
        self.id = id
        self.date = date
        self.spend = spend
    }
}

public struct DashboardSnapshot: Equatable {
    public let tlPer100Km: MeasuredValue<Double>?
    public let averageEnergyPer100Km: MeasuredValue<Double>?
    public let currencyCode: String
    public let primaryPeriodLabel: String
    public let monthlyTotalCost: Double
    public let monthlyTotalEnergy: Double
    public let monthlySessionCount: Int
    public let totalSavingsAmount: Double?
    public let totalSavingsPercent: Double?
    public let gasolineSavingsPercent: Double?
    public let gasolineSavingsAmount: Double?
    public let calculationExplanation: String?
    public let trend: [MonthlyTrendPoint]
    public let recentSessions: [ChargingSession]
    public let breakdown: [CostBreakdown]

    public init(
        tlPer100Km: MeasuredValue<Double>?,
        averageEnergyPer100Km: MeasuredValue<Double>?,
        currencyCode: String,
        primaryPeriodLabel: String = "Bu Ay",
        monthlyTotalCost: Double,
        monthlyTotalEnergy: Double,
        monthlySessionCount: Int,
        totalSavingsAmount: Double?,
        totalSavingsPercent: Double?,
        gasolineSavingsPercent: Double?,
        gasolineSavingsAmount: Double?,
        calculationExplanation: String? = nil,
        trend: [MonthlyTrendPoint],
        recentSessions: [ChargingSession],
        breakdown: [CostBreakdown]
    ) {
        self.tlPer100Km = tlPer100Km
        self.averageEnergyPer100Km = averageEnergyPer100Km
        self.currencyCode = currencyCode
        self.primaryPeriodLabel = primaryPeriodLabel
        self.monthlyTotalCost = monthlyTotalCost
        self.monthlyTotalEnergy = monthlyTotalEnergy
        self.monthlySessionCount = monthlySessionCount
        self.totalSavingsAmount = totalSavingsAmount
        self.totalSavingsPercent = totalSavingsPercent
        self.gasolineSavingsPercent = gasolineSavingsPercent
        self.gasolineSavingsAmount = gasolineSavingsAmount
        self.calculationExplanation = calculationExplanation
        self.trend = trend
        self.recentSessions = recentSessions
        self.breakdown = breakdown
    }
}
