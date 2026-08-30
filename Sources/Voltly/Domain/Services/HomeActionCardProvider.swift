import Foundation

public struct HomeActionCardProvider {
    public init() {}

    public func makeActionCard(from recommendations: [Recommendation]) -> Recommendation? {
        recommendations.first
    }
}
