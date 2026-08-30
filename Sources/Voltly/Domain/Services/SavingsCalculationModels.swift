import Foundation

public enum SavingsCalculationPeriod: String, CaseIterable, Hashable, Sendable {
    case thisMonth
    case last30Days
    case last12Months
    case allTime
}

public enum SavingsConfidenceLevel: String, Equatable, Sendable {
    case high
    case medium
    case low

    public var displayText: String {
        switch self {
        case .high:
            return "Yuksek guven"
        case .medium:
            return "Orta guven"
        case .low:
            return "Dusuk guven"
        }
    }
}

public enum DistanceCalculationMode: String, Equatable, Sendable {
    case odometer
    case energyEstimated = "energy_estimated"
    case hybrid
}

public enum ConsumptionCalculationMode: String, Equatable, Sendable {
    case realData = "real_data"
    case blockAverage = "block_average"
    case historicalEstimated = "historical_estimated"
    case factoryEstimated = "factory_estimated"
    case defaultEstimated = "default_estimated"
}

public enum ConsumptionReferenceSource: String, Equatable, Sendable {
    case historical
    case factory
    case `default`
}

public struct SavingsCalculationMode: Equatable, Sendable {
    public let distance: DistanceCalculationMode
    public let consumption: ConsumptionCalculationMode

    public init(
        distance: DistanceCalculationMode,
        consumption: ConsumptionCalculationMode
    ) {
        self.distance = distance
        self.consumption = consumption
    }
}

public struct CalculationWarning: Equatable, Sendable, Identifiable {
    public let id: String
    public let message: String

    public init(id: String, message: String) {
        self.id = id
        self.message = message
    }
}

public struct ConfidenceReport: Equatable, Sendable {
    public let level: SavingsConfidenceLevel
    public let score: Int
    public let explanation: String

    public init(level: SavingsConfidenceLevel, score: Int, explanation: String) {
        self.level = level
        self.score = score
        self.explanation = explanation
    }
}

public struct SavingsCalculationDebugInfo: Equatable, Sendable {
    public let rawSessionCount: Int
    public let validSessionCount: Int
    public let suspiciousSessionCount: Int
    public let odometerPointCount: Int
    public let distanceSource: DistanceCalculationMode
    public let consumptionSource: ConsumptionCalculationMode
    public let invalidReasons: [String]
    public let fallbackTriggered: Bool
    public let rawEnergyTotal: Double
    public let rawCostTotal: Double

    public init(
        rawSessionCount: Int,
        validSessionCount: Int,
        suspiciousSessionCount: Int,
        odometerPointCount: Int,
        distanceSource: DistanceCalculationMode,
        consumptionSource: ConsumptionCalculationMode,
        invalidReasons: [String],
        fallbackTriggered: Bool,
        rawEnergyTotal: Double,
        rawCostTotal: Double
    ) {
        self.rawSessionCount = rawSessionCount
        self.validSessionCount = validSessionCount
        self.suspiciousSessionCount = suspiciousSessionCount
        self.odometerPointCount = odometerPointCount
        self.distanceSource = distanceSource
        self.consumptionSource = consumptionSource
        self.invalidReasons = invalidReasons
        self.fallbackTriggered = fallbackTriggered
        self.rawEnergyTotal = rawEnergyTotal
        self.rawCostTotal = rawCostTotal
    }
}

public struct SavingsSummary: Equatable, Sendable {
    public let period: SavingsCalculationPeriod
    public let totalEnergyKWh: Double
    public let totalEvCost: Double
    public let estimatedDistanceKm: Double
    public let avgConsumptionKWh100km: Double
    public let gasolineEquivalentCost: Double
    public let savingsAmount: Double
    public let savingsPercent: Double?
    public let evCostPer100Km: Double?
    public let gasolineCostPer100Km: Double?
    public let costPerKWh: Double?
    public let sessionCount: Int
    public let confidenceLevel: SavingsConfidenceLevel
    public let confidenceReport: ConfidenceReport
    public let calculationMode: SavingsCalculationMode
    public let warnings: [CalculationWarning]
    public let explanationText: String
    public let consumptionLabel: String
    public let debugInfo: SavingsCalculationDebugInfo?

    public init(
        period: SavingsCalculationPeriod,
        totalEnergyKWh: Double,
        totalEvCost: Double,
        estimatedDistanceKm: Double,
        avgConsumptionKWh100km: Double,
        gasolineEquivalentCost: Double,
        savingsAmount: Double,
        savingsPercent: Double?,
        evCostPer100Km: Double?,
        gasolineCostPer100Km: Double?,
        costPerKWh: Double?,
        sessionCount: Int,
        confidenceLevel: SavingsConfidenceLevel,
        confidenceReport: ConfidenceReport,
        calculationMode: SavingsCalculationMode,
        warnings: [CalculationWarning],
        explanationText: String,
        consumptionLabel: String,
        debugInfo: SavingsCalculationDebugInfo?
    ) {
        self.period = period
        self.totalEnergyKWh = totalEnergyKWh
        self.totalEvCost = totalEvCost
        self.estimatedDistanceKm = estimatedDistanceKm
        self.avgConsumptionKWh100km = avgConsumptionKWh100km
        self.gasolineEquivalentCost = gasolineEquivalentCost
        self.savingsAmount = savingsAmount
        self.savingsPercent = savingsPercent
        self.evCostPer100Km = evCostPer100Km
        self.gasolineCostPer100Km = gasolineCostPer100Km
        self.costPerKWh = costPerKWh
        self.sessionCount = sessionCount
        self.confidenceLevel = confidenceLevel
        self.confidenceReport = confidenceReport
        self.calculationMode = calculationMode
        self.warnings = warnings
        self.explanationText = explanationText
        self.consumptionLabel = consumptionLabel
        self.debugInfo = debugInfo
    }
}

public struct SavingsPiggyBankSummary: Equatable, Sendable {
    public let depositsEquivalent: Int
    public let monthlySubscriptionEquivalent: Int
    public let coffeeEquivalent: Int
    public let dinnerEquivalent: Int

    public init(
        depositsEquivalent: Int,
        monthlySubscriptionEquivalent: Int,
        coffeeEquivalent: Int,
        dinnerEquivalent: Int
    ) {
        self.depositsEquivalent = depositsEquivalent
        self.monthlySubscriptionEquivalent = monthlySubscriptionEquivalent
        self.coffeeEquivalent = coffeeEquivalent
        self.dinnerEquivalent = dinnerEquivalent
    }
}

public struct CarbonSummary: Equatable, Sendable {
    public let avoidedCO2Kg: Double
    public let equivalentTrees: Int
    public let monthlyAvoidedCO2Kg: Double
    public let label: String

    public init(
        avoidedCO2Kg: Double,
        equivalentTrees: Int,
        monthlyAvoidedCO2Kg: Double,
        label: String
    ) {
        self.avoidedCO2Kg = avoidedCO2Kg
        self.equivalentTrees = equivalentTrees
        self.monthlyAvoidedCO2Kg = monthlyAvoidedCO2Kg
        self.label = label
    }
}

public struct SavingsCalculationReport: Equatable, Sendable {
    public let summaries: [SavingsCalculationPeriod: SavingsSummary]
    public let savingsPiggyBank: SavingsPiggyBankSummary
    public let carbonSummary: CarbonSummary

    public init(
        summaries: [SavingsCalculationPeriod: SavingsSummary],
        savingsPiggyBank: SavingsPiggyBankSummary,
        carbonSummary: CarbonSummary
    ) {
        self.summaries = summaries
        self.savingsPiggyBank = savingsPiggyBank
        self.carbonSummary = carbonSummary
    }

    public var thisMonth: SavingsSummary? { summaries[.thisMonth] }
    public var last30Days: SavingsSummary? { summaries[.last30Days] }
    public var last12Months: SavingsSummary? { summaries[.last12Months] }
    public var allTime: SavingsSummary? { summaries[.allTime] }
}
