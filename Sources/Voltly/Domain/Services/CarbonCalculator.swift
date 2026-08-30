import Foundation

public struct CarbonCalculator {
    private enum Constants {
        static let avoidedCO2PerKm = 0.12
        static let co2PerTree = 45.0
    }

    public init() {}

    public func calculate(distanceKm: Double) -> (avoidedCO2Kg: Double, equivalentTrees: Int) {
        let safeDistance = max(distanceKm, 0)
        let avoided = (safeDistance * Constants.avoidedCO2PerKm * 10).rounded() / 10
        let trees = Int((avoided / Constants.co2PerTree).rounded(.down))
        return (avoidedCO2Kg: avoided, equivalentTrees: max(trees, 0))
    }
}
