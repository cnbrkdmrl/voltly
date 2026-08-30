import Foundation

public enum AppCurrencyCode: String, Codable, CaseIterable, Identifiable, Sendable {
    case turkishLira = "TRY"
    case euro = "EUR"
    case usDollar = "USD"

    public var id: String {
        rawValue
    }

    public var symbol: String {
        switch self {
        case .turkishLira:
            return "₺"
        case .euro:
            return "€"
        case .usDollar:
            return "$"
        }
    }
}
