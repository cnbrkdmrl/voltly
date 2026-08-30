import Foundation

public struct SessionCSVRowMapper {
    public init() {}

    public var header: [String] {
        [
            "Date",
            "Vehicle",
            "Station",
            "Operator",
            "Charger Type",
            "Start SOC",
            "End SOC",
            "Energy (kWh)",
            "Duration (min)",
            "Total Price",
            "Currency",
            "Odometer (km)",
            "Note"
        ]
    }

    public func makeRow(
        session: ChargingSession,
        vehicleDisplayName: String?
    ) -> [String] {
        [
            CSVValueFormatter.date(session.sessionDate),
            vehicleDisplayName ?? "",
            session.locationName ?? "",
            session.stationBrand ?? "",
            session.chargeMethod.titleTR,
            CSVValueFormatter.soc(session.socStart),
            CSVValueFormatter.soc(session.socEnd),
            CSVValueFormatter.decimal(session.energyKWh),
            CSVValueFormatter.integer(session.durationMin),
            CSVValueFormatter.decimal(session.priceTotal),
            session.currencyCode,
            CSVValueFormatter.decimal(session.odometerKM),
            session.notes ?? ""
        ]
    }
}

public enum CSVValueFormatter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    public static func date(_ value: Date) -> String {
        dateFormatter.string(from: value)
    }

    public static func decimal(_ value: Double?) -> String {
        guard let value else { return "" }
        return decimalFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    public static func decimal(_ value: Double) -> String {
        decimalFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    public static func integer(_ value: Int?) -> String {
        guard let value else { return "" }
        return String(value)
    }

    public static func soc(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(Int(value.rounded()))
    }

    public static func vehicleName(_ vehicle: Vehicle) -> String {
        "\(vehicle.brand) \(vehicle.model)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
