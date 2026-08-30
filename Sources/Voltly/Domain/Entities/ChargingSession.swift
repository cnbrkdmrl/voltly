import Foundation

public struct ChargingSession: Identifiable, Equatable {
    public let id: UUID
    public let vehicleID: UUID
    public var sessionDate: Date
    public var chargeMethod: ChargeMethod
    public var stationBrand: String?
    public var locationName: String?
    public var priceTotal: Double
    public var currencyCode: String
    public var energyKWh: Double?
    public var energyIsEstimated: Bool
    public var socStart: Double
    public var socEnd: Double
    public var isFullCharge: Bool
    public var durationMin: Int?
    public var odometerKM: Double?
    public var outsideTempC: Double?
    public var weatherCondition: String?
    public var rangeGainedKmEstimate: Double?
    public var contextTags: [ChargeContextTag]
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date

    public var stationDisplayName: String {
        let brand = stationBrand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let location = locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !brand.isEmpty, !location.isEmpty {
            return "\(brand) • \(location)"
        }
        if !brand.isEmpty {
            return brand
        }
        if !location.isEmpty {
            return location
        }
        return "Konum yok"
    }

    public var tlPerKWh: Double? {
        guard let energyKWh, energyKWh > 0 else { return nil }
        return priceTotal / energyKWh
    }

    public init(
        id: UUID = UUID(),
        vehicleID: UUID,
        sessionDate: Date = .now,
        chargeMethod: ChargeMethod,
        stationBrand: String? = nil,
        locationName: String? = nil,
        priceTotal: Double,
        currencyCode: String = "TRY",
        energyKWh: Double? = nil,
        energyIsEstimated: Bool = false,
        socStart: Double,
        socEnd: Double,
        isFullCharge: Bool = false,
        durationMin: Int? = nil,
        odometerKM: Double? = nil,
        outsideTempC: Double? = nil,
        weatherCondition: String? = nil,
        rangeGainedKmEstimate: Double? = nil,
        contextTags: [ChargeContextTag] = [],
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.sessionDate = sessionDate
        self.chargeMethod = chargeMethod
        self.stationBrand = stationBrand
        self.locationName = locationName
        self.priceTotal = priceTotal
        self.currencyCode = currencyCode
        self.energyKWh = energyKWh
        self.energyIsEstimated = energyIsEstimated
        self.socStart = socStart
        self.socEnd = socEnd
        self.isFullCharge = isFullCharge
        self.durationMin = durationMin
        self.odometerKM = odometerKM
        self.outsideTempC = outsideTempC
        self.weatherCondition = weatherCondition
        self.rangeGainedKmEstimate = rangeGainedKmEstimate
        self.contextTags = contextTags
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
