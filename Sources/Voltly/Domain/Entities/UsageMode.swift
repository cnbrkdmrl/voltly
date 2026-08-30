import Foundation

public enum UsageMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case savingsFocused
    case balanced
    case speedFocused

    public var id: String { rawValue }

    public var titleTR: String {
        switch self {
        case .savingsFocused:
            return "Tasarruf odaklı"
        case .balanced:
            return "Dengeli"
        case .speedFocused:
            return "Hız odaklı"
        }
    }

    public var subtitleTR: String {
        switch self {
        case .savingsFocused:
            return "AC/Ev ağırlığı ve maliyet optimizasyonu"
        case .balanced:
            return "Maliyet ve pratikliği dengede tutar"
        case .speedFocused:
            return "Hızlı şarjı daha toleranslı değerlendirir"
        }
    }

    public var iconName: String {
        switch self {
        case .savingsFocused:
            return "leaf.fill"
        case .balanced:
            return "circle.grid.2x2.fill"
        case .speedFocused:
            return "bolt.fill"
        }
    }

    public var dcToleranceMultiplier: Double {
        switch self {
        case .savingsFocused:
            return 0.85
        case .balanced:
            return 1.0
        case .speedFocused:
            return 1.2
        }
    }

    public var savingsAggressionMultiplier: Double {
        switch self {
        case .savingsFocused:
            return 1.2
        case .balanced:
            return 1.0
        case .speedFocused:
            return 0.85
        }
    }
}
