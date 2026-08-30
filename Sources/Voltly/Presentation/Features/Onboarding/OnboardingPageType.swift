import Foundation

/// Onboarding akışındaki her adımın türünü tanımlar.
public enum OnboardingPageType: Int, CaseIterable, Identifiable, Sendable {
    case splash
    case welcome
    case costAnalysis
    case comparison
    case accountChoice

    public var id: Int { rawValue }
}

/// Son adımda kullanıcı tarafından seçilen devam tipini temsil eder.
public enum OnboardingAccountChoice: String, CaseIterable, Identifiable, Sendable {
    case createAccount
    case guest

    public var id: String { rawValue }

    public var launchAccessMode: LaunchAccessMode {
        switch self {
        case .createAccount:
            return .authenticated
        case .guest:
            return .guest
        }
    }
}

/// AC/DC karşılaştırma kartlarındaki seçim tipini temsil eder.
public enum ChargeComparisonType: String, CaseIterable, Identifiable, Sendable {
    case ac = "AC"
    case dc = "DC"

    public var id: String { rawValue }
}
