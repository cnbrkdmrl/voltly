import Foundation

public enum EnergyUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case kilowattHour = "kWh"

    public var id: String {
        rawValue
    }
}
