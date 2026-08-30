import CoreLocation
import Foundation
import MapKit

@MainActor
public final class ChargeMapViewModel: ObservableObject {
    private enum GeocodePolicy {
        // Keeps CLGeocoder usage below Apple's short-window throttling.
        static let maxRequestsPerReload = 24
    }

    @Published public private(set) var pins: [ChargeMapPin] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public var selectedPinID: UUID?
    @Published public var region: MKCoordinateRegion = ChargeMapViewModel.defaultRegion

    private let environment: AppEnvironment
    private var hasLoaded = false
    private var geocodeCache: [String: CLLocationCoordinate2D] = [:]
    private var geocodeFailures: Set<String> = []
    private var geocodeRequestCount = 0

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var selectedPin: ChargeMapPin? {
        guard let selectedPinID else { return nil }
        return pins.first(where: { $0.id == selectedPinID })
    }

    public func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    public func reload() async {
        isLoading = true
        defer { isLoading = false }
        geocodeRequestCount = 0

        do {
            let sessions = try environment.listChargingSessionsUseCase.execute()
                .sorted(by: { $0.sessionDate > $1.sessionDate })

            guard !sessions.isEmpty else {
                pins = []
                selectedPinID = nil
                region = Self.defaultRegion
                errorMessage = nil
                return
            }

            var nextPins: [ChargeMapPin] = []
            nextPins.reserveCapacity(sessions.count)

            for session in sessions {
                let resolved = await resolveCoordinate(for: session)
                nextPins.append(
                    ChargeMapPin(
                        id: session.id,
                        sessionID: session.id,
                        coordinate: resolved.coordinate,
                        stationDisplayName: session.stationDisplayName,
                        chargeMethod: session.chargeMethod,
                        energyKWh: session.energyKWh,
                        totalPrice: session.priceTotal,
                        currencyCode: session.currencyCode,
                        tlPerKWh: session.tlPerKWh,
                        isApproximateLocation: resolved.isApproximate
                    )
                )
            }

            pins = nextPins
            selectedPinID = nextPins.first?.id
            fitAllPins()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            pins = []
            selectedPinID = nil
            region = Self.defaultRegion
        }
    }

    public func fitAllPins() {
        guard !pins.isEmpty else {
            region = Self.defaultRegion
            return
        }
        region = Self.regionCoveringAllPins(pins)
    }

    private func resolveCoordinate(for session: ChargingSession) async -> (coordinate: CLLocationCoordinate2D, isApproximate: Bool) {
        if let parsed = Self.parseCoordinateText(session.locationName) {
            return (parsed, false)
        }

        let queries = candidateQueries(for: session)
        for query in queries {
            let key = Self.normalizeQuery(query)
            if let cached = geocodeCache[key] {
                return (cached, false)
            }
            if geocodeFailures.contains(key) {
                continue
            }
            guard geocodeRequestCount < GeocodePolicy.maxRequestsPerReload else {
                break
            }
            if let geocoded = await geocode(query: query) {
                geocodeRequestCount += 1
                geocodeCache[key] = geocoded
                return (geocoded, false)
            }
            geocodeRequestCount += 1
            geocodeFailures.insert(key)
        }

        return (Self.fallbackCoordinate(for: session.id), true)
    }

    private func candidateQueries(for session: ChargingSession) -> [String] {
        let station = session.stationBrand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let location = session.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var candidates: [String] = []
        if !location.isEmpty, !station.isEmpty {
            candidates.append("\(location), \(station), Türkiye")
            candidates.append("\(location), Türkiye")
            candidates.append("\(station), Türkiye")
        } else if !location.isEmpty {
            candidates.append("\(location), Türkiye")
            candidates.append(location)
        } else if !station.isEmpty {
            candidates.append("\(station), Türkiye")
            candidates.append(station)
        } else {
            candidates.append("Türkiye")
        }

        var deduplicated: [String] = []
        var seen = Set<String>()
        for candidate in candidates {
            let normalized = Self.normalizeQuery(candidate)
            if normalized.isEmpty || seen.contains(normalized) {
                continue
            }
            seen.insert(normalized)
            deduplicated.append(candidate)
        }
        return deduplicated
    }

    private func geocode(query: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    private static func parseCoordinateText(_ text: String?) -> CLLocationCoordinate2D? {
        guard let text else { return nil }
        let parts = text
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let lat = Double(parts[0].replacingOccurrences(of: ",", with: ".")),
              let lon = Double(parts[1].replacingOccurrences(of: ",", with: ".")),
              (-90...90).contains(lat),
              (-180...180).contains(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private static func normalizeQuery(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func regionCoveringAllPins(_ pins: [ChargeMapPin]) -> MKCoordinateRegion {
        guard let first = pins.first?.coordinate else { return defaultRegion }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for pin in pins.dropFirst() {
            minLat = min(minLat, pin.coordinate.latitude)
            maxLat = max(maxLat, pin.coordinate.latitude)
            minLon = min(minLon, pin.coordinate.longitude)
            maxLon = max(maxLon, pin.coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latitudeDelta = max(0.08, (maxLat - minLat) * 1.35)
        let longitudeDelta = max(0.08, (maxLon - minLon) * 1.35)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private static func fallbackCoordinate(for sessionID: UUID) -> CLLocationCoordinate2D {
        let center = defaultRegion.center
        let hash = sessionID.uuidString.unicodeScalars.reduce(0) { partial, scalar in
            partial &+ Int(scalar.value)
        }
        let latOffset = (Double(hash % 41) - 20) * 0.01
        let lonOffset = (Double(hash % 53) - 26) * 0.01
        return CLLocationCoordinate2D(
            latitude: center.latitude + latOffset,
            longitude: center.longitude + lonOffset
        )
    }

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    )
}
