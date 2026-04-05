# Focus — Claude Cheat Sheet

## App
App iOS de productivité avec compagnon IA conversationnel ("Kai"). Single-screen chat. Swift/SwiftUI.

## Langue
Répondre en **français** par défaut.

## Patterns & Conventions
- **MVVM + Services** — état centralisé via `FocusAppStore.shared`
- **Navigation** : single-tab (ChatView). `AppRouter.shared` gère les sheets
- **APIClient** : encoder `.convertToSnakeCase` (camelCase Swift → snake_case JSON auto)
- **AI Chat** : `BackboardService` (thread persistant). `VoiceService` = legacy
- **Feature flags** : `AppConfiguration.swift`
- **Design System** : `ColorTokens`, `.satoshi()` font
- **Localisation** : 3 langues (FR/EN/ES) — `LocalizationManager.swift` (L10n) + `.strings`

## Fichiers clés
| Domaine | Fichier |
|---------|---------|
| État global | `Core/AppStore.swift` |
| API HTTP | `Core/APIClient.swift` |
| Chat IA | `ViewModels/ChatViewModel.swift`, `Services/BackboardService.swift` |
| Voice LiveKit | `Services/LiveKitVoiceService.swift`, `ViewModels/VoiceCallViewModel.swift` |
| Abonnements | `Services/SubscriptionManager.swift` (StoreKit 2 natif) |
| Navigation | `Navigation/Navigation.swift` |
| Modèles | `Models/Models.swift` |

## Deploy
```bash
# TestFlight
source .env.local && FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="$FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD" bundle exec fastlane beta
```
Bundle ID : `com.jep.volta` | Team ID : `62NW6K29QN`

## NE PAS FAIRE
- Ne jamais hardcoder de clés API — utiliser `Config.plist` ou `.env.local`
- Ne pas toucher `BackboardService` sans comprendre le thread model (messages persistés côté serveur)
- Ne pas utiliser `VoiceService` pour du nouveau code voice → utiliser `LiveKitVoiceService`

## Web App
Repo : `/Users/jperrama/Developer/iOS_Swift_Applications/focus-web` (Next.js, même thread Backboard)
