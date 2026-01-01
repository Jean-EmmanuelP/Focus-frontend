// MARK: - Design System Tokens
// Centralized design tokens for easy theming

import SwiftUI
import UIKit

/// All color tokens for the app - Opal-inspired calm design
enum ColorTokens {
    // MARK: - Backgrounds (Deep black for sacred space feel)
    static let background = Color(hex: "#050508")
    static let surface = Color(hex: "#0F1014")
    static let surfaceElevated = Color(hex: "#1A1B21")

    // MARK: - Primary (Sky blue - calm, serene)
    static let primaryStart = Color(hex: "#5AC8FA")  // iOS Sky Blue
    static let primaryEnd = Color(hex: "#64D2FF")    // Lighter sky blue
    static let primarySoft = Color(hex: "#5AC8FA").opacity(0.12)
    static let primaryGlow = Color(hex: "#5AC8FA").opacity(0.3)

    // MARK: - Accent (Subtle teal for variety)
    static let accent = Color(hex: "#4ECDC4")
    static let accentSoft = Color(hex: "#4ECDC4").opacity(0.12)

    // MARK: - Text
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#A0A0A8")
    static let textMuted = Color(hex: "#5A5A64")

    // MARK: - States
    static let success = Color(hex: "#34C759")  // iOS Green
    static let warning = Color(hex: "#FFD60A")  // iOS Yellow
    static let error = Color(hex: "#FF453A")    // iOS Red

    // MARK: - Borders
    static let border = Color.white.opacity(0.08)
    static let borderActive = Color(hex: "#5AC8FA").opacity(0.4)

    // MARK: - Gradients (Serene blue gradients)
    static let primaryGradient = LinearGradient(
        colors: [primaryStart, primaryEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let primaryGradientVertical = LinearGradient(
        colors: [primaryStart, primaryEnd],
        startPoint: .top,
        endPoint: .bottom
    )

    // Legacy aliases for compatibility
    static let fireGradient = primaryGradient
    static let fireGradientVertical = primaryGradientVertical

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
        colors: [success, Color(hex: "#30D158")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Accent gradient (teal)
    static let accentGradient = LinearGradient(
        colors: [accent, Color(hex: "#5FE3D9")],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// Typography tokens using Satoshi font
enum TypographyTokens {
    // MARK: - Satoshi Font Names
    enum Satoshi {
        static let light = "Satoshi-Light"
        static let regular = "Satoshi-Regular"
        static let medium = "Satoshi-Medium"
        static let bold = "Satoshi-Bold"
        static let black = "Satoshi-Black"
        static let italic = "Satoshi-Italic"
        static let lightItalic = "Satoshi-LightItalic"
        static let mediumItalic = "Satoshi-MediumItalic"
        static let boldItalic = "Satoshi-BoldItalic"
        static let blackItalic = "Satoshi-BlackItalic"
    }

    struct FontStyle {
        let size: CGFloat
        let weight: Font.Weight
        let lineHeight: CGFloat?
        let letterSpacing: CGFloat?

        var font: Font {
            // Map weight to Satoshi font name
            let fontName: String
            switch weight {
            case .light, .thin, .ultraLight:
                fontName = Satoshi.light
            case .regular:
                fontName = Satoshi.regular
            case .medium:
                fontName = Satoshi.medium
            case .semibold, .bold:
                fontName = Satoshi.bold
            case .heavy, .black:
                fontName = Satoshi.black
            default:
                fontName = Satoshi.regular
            }

            // Try custom font, fallback to system
            if let _ = UIFont(name: fontName, size: size) {
                return Font.custom(fontName, size: size)
            }
            return Font.system(size: size, weight: weight)
        }
    }

    static let heading1 = FontStyle(size: 32, weight: .bold, lineHeight: 40, letterSpacing: -0.5)
    static let heading2 = FontStyle(size: 24, weight: .semibold, lineHeight: 32, letterSpacing: nil)
    static let subtitle = FontStyle(size: 18, weight: .medium, lineHeight: 24, letterSpacing: nil)
    static let body = FontStyle(size: 16, weight: .regular, lineHeight: 22, letterSpacing: nil)
    static let caption = FontStyle(size: 14, weight: .regular, lineHeight: 18, letterSpacing: nil)
    static let label = FontStyle(size: 12, weight: .medium, lineHeight: 16, letterSpacing: 0.5)
}

// MARK: - Font Extension for Satoshi
extension Font {
    static func satoshi(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .light, .thin, .ultraLight:
            fontName = TypographyTokens.Satoshi.light
        case .regular:
            fontName = TypographyTokens.Satoshi.regular
        case .medium:
            fontName = TypographyTokens.Satoshi.medium
        case .semibold, .bold:
            fontName = TypographyTokens.Satoshi.bold
        case .heavy, .black:
            fontName = TypographyTokens.Satoshi.black
        default:
            fontName = TypographyTokens.Satoshi.regular
        }

        if let _ = UIFont(name: fontName, size: size) {
            return Font.custom(fontName, size: size)
        }
        return Font.system(size: size, weight: weight)
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
    static let xl: CGFloat = 24
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
