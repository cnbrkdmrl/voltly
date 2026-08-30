import CoreLocation
import Foundation

public struct ChargeMapPin: Identifiable {
    public let id: UUID
    public let sessionID: UUID
    public let coordinate: CLLocationCoordinate2D
    public let stationDisplayName: String
    public let chargeMethod: ChargeMethod
    public let energyKWh: Double?
    public let totalPrice: Double
    public let currencyCode: String
    public let tlPerKWh: Double?
    public let isApproximateLocation: Bool

    public init(
        id: UUID,
        sessionID: UUID,
        coordinate: CLLocationCoordinate2D,
        stationDisplayName: String,
        chargeMethod: ChargeMethod,
        energyKWh: Double?,
        totalPrice: Double,
        currencyCode: String,
        tlPerKWh: Double?,
        isApproximateLocation: Bool
    ) {
        self.id = id
        self.sessionID = sessionID
        self.coordinate = coordinate
        self.stationDisplayName = stationDisplayName
        self.chargeMethod = chargeMethod
        self.energyKWh = energyKWh
        self.totalPrice = totalPrice
        self.currencyCode = currencyCode
        self.tlPerKWh = tlPerKWh
        self.isApproximateLocation = isApproximateLocation
    }
}
