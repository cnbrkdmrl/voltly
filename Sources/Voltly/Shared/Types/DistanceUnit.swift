import Foundation

public enum DistanceUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case km = "km"
    case mile = "mile"

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .km:
            return "km"
        case .mile:
            return "mile"
        }
    }
}
