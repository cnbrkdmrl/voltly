import Foundation

public struct CostBreakdown: Equatable {
    public let method: ChargeMethod
    public let totalCost: Double
    public let totalEnergy: Double
    public let sessionCount: Int

    public init(method: ChargeMethod, totalCost: Double, totalEnergy: Double, sessionCount: Int) {
        self.method = method
        self.totalCost = totalCost
        self.totalEnergy = totalEnergy
        self.sessionCount = sessionCount
    }
}
