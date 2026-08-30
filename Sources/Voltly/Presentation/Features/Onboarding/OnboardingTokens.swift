import SwiftUI

/// Onboarding akışındaki ortak ölçü, köşe ve animasyon değerlerini toplar.
public enum OnboardingTokens {
    public enum Spacing {
        public static let xxSmall: CGFloat = 4
        public static let xSmall: CGFloat = 6
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 10
        public static let large: CGFloat = 14
        public static let xLarge: CGFloat = 16
        public static let xxLarge: CGFloat = 20
    }

    public enum CornerRadius {
        public static let tiny: CGFloat = 6
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xLarge: CGFloat = 18
    }

    public enum Size {
        public static let primaryButtonHeight: CGFloat = 54
        public static let splashLogo: CGFloat = 110
        public static let splashHalo: CGFloat = 132
        public static let progressActiveWidth: CGFloat = 34
        public static let progressInactiveWidth: CGFloat = 14
        public static let progressHeight: CGFloat = 6
        public static let miniTrendHeight: CGFloat = 84
        public static let batteryWidth: CGFloat = 96
        public static let batteryHeight: CGFloat = 36
    }

    public enum Motion {
        public static let tinyOffset: CGFloat = 6
        public static let smallOffset: CGFloat = 8
        public static let mediumOffset: CGFloat = 10
        public static let largeOffset: CGFloat = 14

        public static let splashDuration: Double = 0.9
        public static let quickDuration: Double = 0.24
        public static let regularDuration: Double = 0.30
        public static let cardDuration: Double = 0.36
        public static let trendDuration: Double = 0.45
    }

    public static func reducedOffset(_ value: CGFloat, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 0 : value
    }

    public static func reducedScale(_ value: CGFloat, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 1 : value
    }

    public static func revealAnimation(
        reduceMotion: Bool,
        delay: Double = 0
    ) -> Animation {
        if reduceMotion {
            return .easeOut(duration: 0.18).delay(delay * 0.2)
        }
        return .easeOut(duration: Motion.regularDuration).delay(delay)
    }
}
