// MARK: - Design System Tokens
// Centralized design tokens for easy theming
// Light Mode - Professional Blue/White Theme with Inter font

import SwiftUI
import UIKit

/// All color tokens for the app - Light Mode Professional Theme
enum ColorTokens {
    // MARK: - Backgrounds (Light)
    static let background = Color(hex: "#FFFFFF")
    static let surface = Color(hex: "#F8FAFC")
    static let surfaceElevated = Color(hex: "#FFFFFF")

    // MARK: - Primary (Professional Blue)
    static let primaryStart = Color(hex: "#2563EB")  // Blue 600
    static let primaryEnd = Color(hex: "#3B82F6")    // Blue 500
    static let primarySoft = Color(hex: "#2563EB").opacity(0.08)
    static let primaryGlow = Color(hex: "#2563EB").opacity(0.15)
    static let primaryLight = Color(hex: "#DBEAFE") // Blue 100

    // MARK: - Text (Dark on Light)
    static let textPrimary = Color(hex: "#0F172A")   // Slate 900
    static let textSecondary = Color(hex: "#475569") // Slate 600
    static let textMuted = Color(hex: "#94A3B8")     // Slate 400

    // MARK: - States
    static let success = Color(hex: "#10B981")       // Emerald 500
    static let warning = Color(hex: "#F59E0B")       // Amber 500
    static let error = Color(hex: "#EF4444")         // Red 500

    // MARK: - Borders
    static let border = Color(hex: "#E2E8F0")        // Slate 200
    static let borderActive = Color(hex: "#2563EB").opacity(0.3)

    // MARK: - Shadows
    static let shadowLight = Color.black.opacity(0.04)
    static let shadowMedium = Color.black.opacity(0.08)

    // MARK: - Gradients
    static let fireGradient = LinearGradient(
        colors: [primaryStart, primaryEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let fireGradientVertical = LinearGradient(
        colors: [primaryStart, primaryEnd],
        startPoint: .top,
        endPoint: .bottom
    )

    // Disabled gradient for buttons
    static let disabledGradient = LinearGradient(
        colors: [textMuted, textMuted],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Surface as gradient (for type consistency)
    static let surfaceGradient = LinearGradient(
        colors: [surface, surface],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Success gradient (green)
    static let successGradient = LinearGradient(
        colors: [success, Color(hex: "#34D399")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Accent Colors
    static let accentBlue = Color(hex: "#2563EB")
    static let accentIndigo = Color(hex: "#4F46E5")
    static let accentPurple = Color(hex: "#7C3AED")
}

/// Typography tokens using Inter font (Google Fonts)
enum TypographyTokens {
    // MARK: - Inter Font Names
    enum Inter {
        static let thin = "Inter-Thin"
        static let extraLight = "Inter-ExtraLight"
        static let light = "Inter-Light"
        static let regular = "Inter-Regular"
        static let medium = "Inter-Medium"
        static let semiBold = "Inter-SemiBold"
        static let bold = "Inter-Bold"
        static let extraBold = "Inter-ExtraBold"
        static let black = "Inter-Black"
    }

    struct FontStyle {
        let size: CGFloat
        let weight: Font.Weight
        let lineHeight: CGFloat?
        let letterSpacing: CGFloat?

        var font: Font {
            // Map weight to Inter font name
            let fontName: String
            switch weight {
            case .thin:
                fontName = Inter.thin
            case .ultraLight:
                fontName = Inter.extraLight
            case .light:
                fontName = Inter.light
            case .regular:
                fontName = Inter.regular
            case .medium:
                fontName = Inter.medium
            case .semibold:
                fontName = Inter.semiBold
            case .bold:
                fontName = Inter.bold
            case .heavy:
                fontName = Inter.extraBold
            case .black:
                fontName = Inter.black
            default:
                fontName = Inter.regular
            }

            // Try custom font, fallback to system
            if let _ = UIFont(name: fontName, size: size) {
                return Font.custom(fontName, size: size)
            }
            // Fallback to SF Pro (system font) which looks similar to Inter
            return Font.system(size: size, weight: weight, design: .default)
        }
    }

    static let heading1 = FontStyle(size: 28, weight: .bold, lineHeight: 36, letterSpacing: -0.5)
    static let heading2 = FontStyle(size: 22, weight: .semibold, lineHeight: 28, letterSpacing: -0.3)
    static let subtitle = FontStyle(size: 17, weight: .semibold, lineHeight: 24, letterSpacing: nil)
    static let body = FontStyle(size: 15, weight: .regular, lineHeight: 22, letterSpacing: nil)
    static let caption = FontStyle(size: 13, weight: .regular, lineHeight: 18, letterSpacing: nil)
    static let label = FontStyle(size: 11, weight: .medium, lineHeight: 14, letterSpacing: 0.5)
}

// MARK: - Font Extension for Inter
extension Font {
    /// Creates an Inter font with the specified size and weight
    /// Falls back to SF Pro (system) if Inter is not available
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .thin:
            fontName = TypographyTokens.Inter.thin
        case .ultraLight:
            fontName = TypographyTokens.Inter.extraLight
        case .light:
            fontName = TypographyTokens.Inter.light
        case .regular:
            fontName = TypographyTokens.Inter.regular
        case .medium:
            fontName = TypographyTokens.Inter.medium
        case .semibold:
            fontName = TypographyTokens.Inter.semiBold
        case .bold:
            fontName = TypographyTokens.Inter.bold
        case .heavy:
            fontName = TypographyTokens.Inter.extraBold
        case .black:
            fontName = TypographyTokens.Inter.black
        default:
            fontName = TypographyTokens.Inter.regular
        }

        if let _ = UIFont(name: fontName, size: size) {
            return Font.custom(fontName, size: size)
        }
        return Font.system(size: size, weight: weight, design: .default)
    }

    /// Alias for backward compatibility - maps to Inter
    static func satoshi(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return inter(size, weight: weight)
    }
}

/// Spacing tokens
enum SpacingTokens {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Border radius tokens
enum RadiusTokens {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let full: CGFloat = 9999
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions for Typography
extension View {
    func typography(_ style: TypographyTokens.FontStyle) -> some View {
        self.font(style.font)
    }

    func heading1() -> some View {
        self.typography(TypographyTokens.heading1)
    }

    func heading2() -> some View {
        self.typography(TypographyTokens.heading2)
    }

    func subtitle() -> some View {
        self.typography(TypographyTokens.subtitle)
    }

    func bodyText() -> some View {
        self.typography(TypographyTokens.body)
    }

    func caption() -> some View {
        self.typography(TypographyTokens.caption)
            .foregroundColor(ColorTokens.textSecondary)
    }

    func label() -> some View {
        self.typography(TypographyTokens.label)
            .textCase(.uppercase)
    }
}

// MARK: - Shadow Extensions
extension View {
    func cardShadow() -> some View {
        self.shadow(color: ColorTokens.shadowLight, radius: 8, x: 0, y: 2)
            .shadow(color: ColorTokens.shadowMedium, radius: 1, x: 0, y: 1)
    }

    func elevatedShadow() -> some View {
        self.shadow(color: ColorTokens.shadowMedium, radius: 16, x: 0, y: 4)
    }
}
