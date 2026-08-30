import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum AppTheme {
    public static let homeColor: Color = Color(red: 0.23, green: 0.66, blue: 0.52)
    public static let publicACColor: Color = Color(red: 0.07, green: 0.72, blue: 0.79)
    public static let publicDCColor: Color = Color(red: 0.97, green: 0.55, blue: 0.22)
    public static let dcAccent: Color = Color(red: 0.51, green: 0.36, blue: 0.95)
    #if os(iOS)
    public static let heroBackground: Color = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 1)
                : UIColor(red: 0.13, green: 0.21, blue: 0.34, alpha: 1)
        }
    )
    public static let surface: Color = Color(uiColor: .secondarySystemBackground)
    public static let overlaySurface: Color = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.white.withAlphaComponent(0.72)
        }
    )
    public static let elevatedSurface: Color = Color(
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? .tertiarySystemBackground
                : .systemBackground
        }
    )
    #elseif os(macOS)
    public static let heroBackground: Color = Color(
        nsColor: NSColor(name: nil) { appearance in
            let resolvedAppearance = appearance.bestMatch(from: [.darkAqua, .aqua])
            if resolvedAppearance == .darkAqua {
                return NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.20, alpha: 1)
            }
            return NSColor(calibratedRed: 0.13, green: 0.21, blue: 0.34, alpha: 1)
        }
    )
    public static let surface: Color = Color(nsColor: .windowBackgroundColor)
    public static let overlaySurface: Color = Color(
        nsColor: NSColor(name: nil) { appearance in
            let resolvedAppearance = appearance.bestMatch(from: [.darkAqua, .aqua])
            if resolvedAppearance == .darkAqua {
                return NSColor.white.withAlphaComponent(0.12)
            }
            return NSColor.white.withAlphaComponent(0.72)
        }
    )
    public static let elevatedSurface: Color = Color(nsColor: .controlBackgroundColor)
    #else
    public static let heroBackground: Color = Color(red: 0.08, green: 0.12, blue: 0.2)
    public static let surface: Color = Color(red: 0.96, green: 0.97, blue: 0.99)
    public static let overlaySurface: Color = Color.white.opacity(0.72)
    public static let elevatedSurface: Color = .white
    #endif
}
