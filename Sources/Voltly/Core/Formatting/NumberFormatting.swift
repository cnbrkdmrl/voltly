import Foundation

public enum NumberFormatting {
    private static let tryFormatter = makeCurrencyFormatter(code: "TRY", localeID: "tr_TR")
    private static let usdFormatter = makeCurrencyFormatter(code: "USD", localeID: "en_US")
    private static let eurFormatter = makeCurrencyFormatter(code: "EUR", localeID: "de_DE")
    private static let gbpFormatter = makeCurrencyFormatter(code: "GBP", localeID: "en_GB")

    public static func currencyTRY(_ value: Double) -> String {
        currency(value, code: "TRY")
    }

    public static func currency(_ value: Double, code: String) -> String {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let currencyCode = normalizedCode.isEmpty ? "TRY" : normalizedCode
        let formatter = formatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(oneDecimal(value))"
    }

    public static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    public static func twoDecimals(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    public static func percent(_ value: Double) -> String {
        String(format: "%%%.0f", value)
    }

    public static func kWh(_ value: Double) -> String {
        "\(oneDecimal(value)) kWh"
    }

    public static func km(_ value: Double) -> String {
        "\(oneDecimal(value)) km"
    }

    public static func kWhPer100Km(_ value: Double) -> String {
        "\(oneDecimal(value)) kWh/100 km"
    }

    public static func tlPerKWh(_ value: Double, currencyCode: String = "TRY") -> String {
        let symbol = currencySymbol(for: currencyCode)
        return "\(oneDecimal(value)) \(symbol)/kWh"
    }

    public static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func locale(for currencyCode: String) -> Locale {
        switch currencyCode {
        case "TRY": return Locale(identifier: "tr_TR")
        case "USD": return Locale(identifier: "en_US")
        case "EUR": return Locale(identifier: "de_DE")
        case "GBP": return Locale(identifier: "en_GB")
        default: return Locale(identifier: "tr_TR")
        }
    }

    private static func currencySymbol(for code: String) -> String {
        let locale = locale(for: code.uppercased())
        if let symbol = locale.localizedString(forCurrencyCode: code.uppercased()) {
            switch code.uppercased() {
            case "TRY": return "₺"
            case "USD": return "$"
            case "EUR": return "€"
            case "GBP": return "£"
            default: return symbol
            }
        }
        return code.uppercased()
    }

    private static func formatter(for code: String) -> NumberFormatter {
        switch code {
        case "TRY": return tryFormatter
        case "USD": return usdFormatter
        case "EUR": return eurFormatter
        case "GBP": return gbpFormatter
        default:
            return makeCurrencyFormatter(code: code, localeID: "tr_TR")
        }
    }

    private static func makeCurrencyFormatter(code: String, localeID: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale(identifier: localeID)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }
}
