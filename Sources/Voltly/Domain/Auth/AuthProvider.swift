import Foundation

public enum AuthProvider: String, CaseIterable, Codable, Identifiable {
    case apple
    case google
    case email
    case guest

    public var id: String { rawValue }

    public var titleTR: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "Email"
        case .guest: return "Misafir"
        }
    }
}
