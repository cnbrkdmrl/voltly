import SwiftUI

/// Onboarding ekranlarının renk ve yüzey stilini merkezileştirir.
public enum OnboardingStyle {
    public static let accent = Color(red: 0.95, green: 0.68, blue: 0.18)
    public static let accentSoft = Color(red: 0.98, green: 0.82, blue: 0.48)
    public static let accentDark = Color(red: 0.87, green: 0.56, blue: 0.1)

    public static func background(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.09),
                    Color(red: 0.09, green: 0.09, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white,
                Color(red: 0.99, green: 0.98, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.16) : Color.white
    }

    public static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.58)
    }

    public static func shadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.09)
    }
}
