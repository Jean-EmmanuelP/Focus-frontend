import Foundation

/// Configuration globale de l'application
enum AppConfiguration {
    // MARK: - Environment
    enum Environment {
        case development
        case staging
        case production
        
        static var current: Environment {
            #if DEBUG
            return .development
            #else
            return .production
            #endif
        }
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        /// Active/désactive les quests (écran optionnel)
        static let questsEnabled = true
        
        /// Active/désactive les analytics
        static let analyticsEnabled = false
        
        /// Active/désactive les notifications
        static let notificationsEnabled = false
        
        /// Active/désactive le mode premium
        static let premiumEnabled = true
    }
    
    // MARK: - API Configuration
    struct API {
        static var baseURL: String {
            switch Environment.current {
            case .development:
                return "https://dev-api.firelevel.app/v1"
            case .staging:
                return "https://staging-api.firelevel.app/v1"
            case .production:
                return "https://api.firelevel.app/v1"
            }
        }
        
        static let timeout: TimeInterval = 30
        static let maxRetries = 3
    }
    
    // MARK: - App Info
    struct Info {
        static let appName = "Volta"
        static let version = "1.0.0"
        static let buildNumber = "1"
        
        static var fullVersion: String {
            "\(version) (\(buildNumber))"
        }
    }
    
    // MARK: - Social Links
    struct Social {
        static let inviteBaseURL = "https://firelevel.app/invite"
        static let communityURL = "https://firelevel.app/community"
        static let supportEmail = "support@firelevel.app"
        static let twitterHandle = "@firelevel"
    }
    
    // MARK: - Limits
    struct Limits {
        /// Nombre maximum de quests pour les utilisateurs free
        static let maxQuestsFree = 3
        
        /// Nombre maximum de quests pour les utilisateurs premium
        static let maxQuestsPremium = 999
        
        /// Nombre maximum de rituels quotidiens
        static let maxRituals = 10
        
        /// Durée minimum d'une session de focus (minutes)
        static let minSessionDuration = 5
        
        /// Durée maximum d'une session de focus (minutes)
        static let maxSessionDuration = 180
        
        /// Durées prédéfinies pour les sessions
        static let presetDurations = [25, 50, 90]
    }
    
    // MARK: - Gamification
    struct Gamification {
        /// XP nécessaire pour passer au niveau suivant (formule : level * baseXP)
        static let baseXPPerLevel = 1000
        
        /// XP gagné pour une session de focus complétée
        static let xpPerFocusSession = 50
        
        /// XP gagné pour un rituel complété
        static let xpPerRitualCompleted = 10
        
        /// XP gagné pour un check-in matinal
        static let xpPerMorningCheckIn = 30
        
        /// XP gagné pour une review du soir
        static let xpPerEveningReview = 30
        
        /// XP bonus pour un streak de 7 jours
        static let xpBonusWeekStreak = 100
        
        /// XP bonus pour un streak de 30 jours
        static let xpBonusMonthStreak = 500
    }
    
    // MARK: - UI Configuration
    struct UI {
        /// Durée des animations par défaut
        static let defaultAnimationDuration: Double = 0.3
        
        /// Active/désactive les animations avancées
        static let advancedAnimations = true
        
        /// Active/désactive les effets de glow
        static let glowEffects = true
        
        /// Active/désactive le mode dark forcé
        static let forceDarkMode = true
    }
    
    // MARK: - Debug
    struct Debug {
        /// Active les logs détaillés
        static let verboseLogging = Environment.current == .development

        /// Active les logs réseau
        static let networkLogging = Environment.current == .development

        /// Affiche les informations de debug dans l'UI
        static let showDebugInfo = Environment.current == .development

        /// Force l'affichage de l'onboarding meme si deja complete (dev only)
        /// Mettre a true pour tester/voir l'onboarding a volonte
        static let forceShowOnboarding = false

        /// Skip directement au paywall pour tester (dev only)
        static let skipToPaywall = false
    }
}

// MARK: - Helper pour calculer l'XP requis
extension AppConfiguration.Gamification {
    static func xpRequiredForLevel(_ level: Int) -> Int {
        return level * baseXPPerLevel
    }
    
    static func levelForXP(_ xp: Int) -> Int {
        return xp / baseXPPerLevel
    }
}

// MARK: - Helper pour les feature flags
extension AppConfiguration.FeatureFlags {
    static var isProduction: Bool {
        AppConfiguration.Environment.current == .production
    }
    
    static var isDevelopment: Bool {
        AppConfiguration.Environment.current == .development
    }
}
