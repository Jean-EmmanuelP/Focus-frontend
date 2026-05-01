import SwiftUI

// MARK: - ChallengeType Visual Identity (per-type ambient hue)

extension ChallengeType {

    /// Per-type primary hue — used for icons and small accents
    var primaryColor: Color {
        switch self {
        case .wakeup:     return Color(hex: "#FFB547")  // amber sunrise
        case .gym:        return Color(hex: "#F87171")  // red intensity
        case .meditation: return Color(hex: "#86EFAC")  // sage green calm
        case .reading:    return Color(hex: "#C4B5FD")  // violet evening
        case .custom:     return ColorTokens.brand     // brand orange
        }
    }

    /// Soft tint for card backgrounds (15% opacity of primary)
    var softColor: Color {
        primaryColor.opacity(0.15)
    }

    /// Per-type gradient for hero buttons or banners
    var gradient: LinearGradient {
        switch self {
        case .wakeup:
            return LinearGradient(colors: [Color(hex: "#FFD27A"), Color(hex: "#FF8A3D")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gym:
            return LinearGradient(colors: [Color(hex: "#FCA5A5"), Color(hex: "#EF4444")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .meditation:
            return LinearGradient(colors: [Color(hex: "#A7F3D0"), Color(hex: "#34D399")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .reading:
            return LinearGradient(colors: [Color(hex: "#DDD6FE"), Color(hex: "#8B5CF6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .custom:
            return ColorTokens.brandGradient
        }
    }

    /// Large emoji for empty states
    var ambientEmoji: String {
        switch self {
        case .wakeup:     return "🌅"
        case .gym:        return "💪"
        case .meditation: return "🧘"
        case .reading:    return "📖"
        case .custom:     return "⭐"
        }
    }

    /// Motivational tagline
    var motivationalLine: String {
        switch self {
        case .wakeup:     return "Les matins forgent les champions"
        case .gym:        return "Chaque seance compte"
        case .meditation: return "Le calme est une force"
        case .reading:    return "Un livre, une vie differente"
        case .custom:     return "Ton defi, ta victoire"
        }
    }

    /// Verification screen message
    var verificationMessage: String {
        switch self {
        case .wakeup:     return "Prouve que tu es debout !"
        case .gym:        return "Montre ta progression !"
        case .meditation: return "Prends une minute pour toi"
        case .reading:    return "Bonne lecture ce soir"
        case .custom:     return "Prouve-le maintenant"
        }
    }

    /// Daily proof — one photo per day
    var steps: [ChallengeStep] {
        switch self {
        case .wakeup:
            return [ChallengeStep(id: "selfie", label: "Photo du matin", points: 1, inputType: .camera)]
        case .gym:
            return [ChallengeStep(id: "selfie", label: "Photo du jour", points: 1, inputType: .camera)]
        case .meditation:
            return [ChallengeStep(id: "selfie", label: "Photo zen", points: 1, inputType: .camera)]
        case .reading:
            return [ChallengeStep(id: "selfie", label: "Photo lecture", points: 1, inputType: .camera)]
        case .custom:
            return [ChallengeStep(id: "selfie", label: "Preuve photo", points: 1, inputType: .camera)]
        }
    }
}
