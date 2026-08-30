import Foundation

public struct SavingsEquivalentsConfig: Equatable, Sendable {
    public let gasTankLiters: Double
    public let monthlySubscriptionCost: Double
    public let coffeeCost: Double
    public let dinnerCost: Double

    public init(
        gasTankLiters: Double = 50,
        monthlySubscriptionCost: Double = 200,
        coffeeCost: Double = 150,
        dinnerCost: Double = 800
    ) {
        self.gasTankLiters = gasTankLiters
        self.monthlySubscriptionCost = monthlySubscriptionCost
        self.coffeeCost = coffeeCost
        self.dinnerCost = dinnerCost
    }
}

public struct SavingsEquivalentsCalculator {
    private let config: SavingsEquivalentsConfig

    public init(config: SavingsEquivalentsConfig = .init()) {
        self.config = config
    }

    public func calculate(
        savingsAmount: Double,
        fuelPricePerLiter: Double
    ) -> SavingsPiggyBankSummary {
        let safeSavings = max(0, savingsAmount)
        let safeFuelPrice = max(fuelPricePerLiter, 1)
        let oneTankCost = safeFuelPrice * config.gasTankLiters

        let deposits = Int((safeSavings / oneTankCost).rounded(.down))
        let subscriptions = Int((safeSavings / config.monthlySubscriptionCost).rounded(.down))
        let coffees = Int((safeSavings / config.coffeeCost).rounded(.down))
        let dinners = Int((safeSavings / config.dinnerCost).rounded(.down))

        return SavingsPiggyBankSummary(
            depositsEquivalent: max(0, deposits),
            monthlySubscriptionEquivalent: max(0, subscriptions),
            coffeeEquivalent: max(0, coffees),
            dinnerEquivalent: max(0, dinners)
        )
    }
}
