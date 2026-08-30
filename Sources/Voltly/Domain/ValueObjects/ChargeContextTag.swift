import Foundation

public enum ChargeContextTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case longRoad = "long_road"
    case cityDriving = "city_driving"
    case coldWeather = "cold_weather"
    case hotWeather = "hot_weather"
    case heavyTraffic = "heavy_traffic"
    case other = "other"

    public var id: String { rawValue }

    public var titleTR: String {
        switch self {
        case .longRoad:
            return "Uzun yol"
        case .cityDriving:
            return "Sehir ici"
        case .coldWeather:
            return "Soguk hava"
        case .hotWeather:
            return "Sicak hava"
        case .heavyTraffic:
            return "Yogun trafik"
        case .other:
            return "Diger / ozel not"
        }
    }
}
