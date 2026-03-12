# Focus App - Documentation Claude

## Vue d'ensemble

**Focus** est une application iOS de productivité centrée sur un **compagnon IA conversationnel** (style Replika). L'expérience est 100% chat — un seul écran principal où l'utilisateur parle à son compagnon (par défaut "Kai") pour organiser sa journée, gérer ses tâches, et rester motivé.

---

## Expérience utilisateur

### Écran principal — Chat
- Interface de chat avec avatar 3D animé (Ready Player Me via WebView)
- Mode "Home" (avatar seul + barre de saisie) et mode "Conversation" (messages + avatar en fond)
- Envoi de messages texte et vocaux (transcription via Whisper)
- Appel vocal en temps réel (LiveKit) — FaceTime-style, full screen dark
- Profil du compagnon accessible depuis le header (nom, personnalité, statistiques)

### Onboarding (13 étapes, style Replika)
1. Prénom/Nom → Âge → Pronoms → Social proof → Présentation
2. Questions de personnalisation (wellness goals, life improvements, development areas)
3. Choix d'avatar + nom du compagnon → Création animée → Paywall → Meet companion

### Focus Pulse (Discover Map)
- Carte MapKit montrant les utilisateurs à proximité en session de focus
- Profils Snapchat-style avec stats (temps de focus, streak)
- Bouton "Rejoindre le focus" → démarre une session via l'API
- Encouragements entre utilisateurs

### Abonnement (StoreKit 2 + RevenueCat)
- **Focus Plus** : sessions Focus illimitées, app blocking avancé
- **Focus Max** : tout Plus + appels vocaux illimités, accès prioritaire

---

## Architecture technique

```
Focus/
├── App/FocusApp.swift              # Point d'entrée + deep linking
├── Core/
│   ├── AppStore.swift              # État centralisé (FocusAppStore.shared)
│   ├── APIClient.swift             # Client HTTP
│   ├── FocusSessionActivity.swift  # Live Activities (écran verrouillage)
│   └── SyncManager.swift           # Synchronisation données
├── Models/
│   └── Models.swift                # Modèles domaine
├── ViewModels/
│   ├── ChatViewModel.swift         # Logique chat + Backboard thread
│   ├── VoiceCallViewModel.swift    # Logique appel vocal LiveKit
│   └── DiscoverMapViewModel.swift  # Focus Pulse / carte
├── Services/
│   ├── AuthService.swift           # Authentification (Apple Sign-In)
│   ├── VoiceService.swift          # API voice assistant (text→response)
│   ├── LiveKitVoiceService.swift   # Appels vocaux temps réel
│   ├── BackboardService.swift      # Thread de conversation persistant
│   ├── SubscriptionManager.swift   # StoreKit 2 + RevenueCat
│   ├── ScreenTimeAppBlockerService.swift  # Blocage d'apps (Family Controls)
│   ├── CalendarService.swift       # Sync calendrier
│   ├── DiscoverService.swift       # Focus Pulse API
│   ├── LocationService.swift       # CoreLocation
│   ├── NotificationService.swift   # Push notifications (Firebase)
│   ├── PushNotificationService.swift # Tokens APNs
│   └── MessageQueueService.swift   # File d'attente offline
├── Views/
│   ├── Chat/                       # ChatView, CompanionProfileView, ChatInputBar
│   ├── VoiceCall/                  # VoiceCallView (LiveKit)
│   ├── Discover/                   # DiscoverMapView, NearbyUserProfileCard
│   ├── FocusMap/                   # FocusMapCoachCard, FocusMapStatsOverlay
│   ├── Onboarding/                 # NewOnboardingView (13 steps), LandingPageView
│   ├── Auth/                       # AuthenticationView, LegalDocumentsView
│   ├── Subscription/               # FocusPaywallView, RevenueCatPaywallView
│   ├── Settings/                   # SettingsView, AppBlockerSettings, etc.
│   ├── Avatar/                     # Avatar3DView (Ready Player Me WebView)
│   └── Splash/                     # SplashView, WelcomeLoadingView
├── Navigation/Navigation.swift     # AppRouter + AppTab (single tab: chat)
└── DesignSystem/                   # Tokens visuels & composants
```

**Pattern** : MVVM + Services avec état centralisé via `FocusAppStore.shared`

**Navigation** : Single-tab (ChatView). `AppRouter.shared` gère les sheets (settings, onboarding, paywall, landing page).

---

## Deep Linking

```swift
focus://chat         → Ouvrir le chat (default)
focus://firemode     → Redirigé vers chat (legacy)
focus://dashboard    → Redirigé vers chat (legacy)
focus://starttheday  → Redirigé vers chat (legacy)
```

---

## Widgets

- **Timer Widget** : compte à rebours Live Activity sur l'écran de verrouillage
- **Weekly Goals Widget** : objectifs hebdomadaires dans le widget
- Données partagées via `UserDefaults(suiteName: "group.com.jep.volta")`

---

## Localisation

3 langues supportées : **Français** (défaut), **Anglais**, **Espagnol**

Système hybride :
- Dictionnaires hardcodés dans `LocalizationManager.swift` (L10n)
- Fichiers `.strings` dans `Resources/{lang}.lproj/Localizable.strings`

---

## Déploiement (Fastlane)

**IMPORTANT** : Toujours utiliser le mot de passe app-specific stocké dans `.env.local`

```bash
# TestFlight (beta)
cd /Users/jperrama/Developer/iOS_Swift_Applications/Focus
source .env.local && FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="$FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD" bundle exec fastlane beta

# App Store (release)
cd /Users/jperrama/Developer/iOS_Swift_Applications/Focus
source .env.local && FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="$FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD" bundle exec fastlane release
```

| Commande | Action |
|----------|--------|
| `fastlane build` | Build debug rapide |
| `fastlane version` | Voir version actuelle |
| `fastlane bump` | Incrémenter build number |
| `fastlane beta` | Build + Upload TestFlight |
| `fastlane release` | Build + Upload App Store |

### Infos projet

- **Bundle ID** : `com.jep.volta`
- **Team ID** : `62NW6K29QN`
- **Docs détaillées** : Voir `DEPLOYMENT.md`

---

## Web App (focus-web)

L'app web est un miroir simplifié de l'app iOS :
- Chat avec le compagnon IA (même thread Backboard partagé)
- Landing page avec design identique à l'iOS
- Stack : Next.js + React + TypeScript
- Repo : `/Users/jperrama/Developer/iOS_Swift_Applications/focus-web`
