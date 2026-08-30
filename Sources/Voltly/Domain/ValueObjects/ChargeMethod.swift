import Foundation

public enum ChargeMethod: String, Codable, CaseIterable, Identifiable {
    case home = "home"
    case publicAC = "public_ac"
    case publicDC = "public_dc"

    public var id: String { rawValue }

    public var titleTR: String {
        switch self {
        case .home: return "Ev"
        case .publicAC: return "AC"
        case .publicDC: return "DC"
        }
    }
}
