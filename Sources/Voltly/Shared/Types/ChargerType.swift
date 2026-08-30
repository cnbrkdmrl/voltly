import Foundation

public enum ChargerType: String, Codable, CaseIterable, Identifiable, Sendable {
    case ac = "AC"
    case dc = "DC"

    public var id: String {
        rawValue
    }
}
