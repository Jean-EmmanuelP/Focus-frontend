import SwiftUI

// MARK: - ChallengeType Visual Identity (unified blue)

extension ChallengeType {

    /// All types use the app's primary blue gradient
    var gradient: LinearGradient {
        ColorTokens.primaryGradient
    }

    /// All types use the app's primary blue
    var primaryColor: Color {
        ColorTokens.primaryStart
    }

    /// Soft blue tint for backgrounds
    var softColor: Color {
        ColorTokens.primarySoft
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
