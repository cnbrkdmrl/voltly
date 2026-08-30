import Foundation

public struct SavingsEquivalentItem: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let value: Int
    public let subtitle: String
}

public enum SavingsEquivalencyHelper {
    private enum Constants {
        static let coffeePriceTL: Double = 95
        static let dinnerPriceTL: Double = 350
        static let subscriptionPriceTL: Double = 190
        static let averageGasTankLiters: Double = 50
    }

    public static func buildItems(monthlySavingsTL: Double, fuelPricePerLiter: Double) -> [SavingsEquivalentItem] {
        let safeSavings = max(0, monthlySavingsTL)
        let safeFuelPrice = max(1, fuelPricePerLiter)
        let oneTankCost = safeFuelPrice * Constants.averageGasTankLiters

        return [
            SavingsEquivalentItem(
                title: "Depo benzin",
                value: Int((safeSavings / oneTankCost).rounded(.down)),
                subtitle: "Yaklaşık \(Int(Constants.averageGasTankLiters))L dolum"
            ),
            SavingsEquivalentItem(
                title: "Aylık abonelik",
                value: Int((safeSavings / Constants.subscriptionPriceTL).rounded(.down)),
                subtitle: "Müzik / video aboneliği seviyesinde"
            ),
            SavingsEquivalentItem(
                title: "Kahve",
                value: Int((safeSavings / Constants.coffeePriceTL).rounded(.down)),
                subtitle: "Ortalama zincir kahve fiyatı"
            ),
            SavingsEquivalentItem(
                title: "Akşam yemeği",
                value: Int((safeSavings / Constants.dinnerPriceTL).rounded(.down)),
                subtitle: "2 kişilik ortalama yemek maliyeti"
            )
        ]
    }
}
