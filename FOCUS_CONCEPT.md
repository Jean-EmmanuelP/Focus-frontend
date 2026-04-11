# Focus — App Concept

## Le problème

Les apps de productivité traditionnelles (Notion, Todoist, Forest...) sont des outils froids — des listes, des timers, des tableaux. Elles demandent de la discipline et de la motivation que l'utilisateur n'a souvent pas. Le résultat : les gens téléchargent ces apps, les utilisent 2 semaines, puis les abandonnent.

La vraie productivité ne vient pas d'un outil, elle vient d'une relation — quelqu'un qui te connaît, qui te pousse, qui s'adapte à toi.

## La solution : Focus

**Focus est un compagnon IA de productivité.** Pas un outil, pas une liste de tâches — un compagnon intelligent qui vit dans ton téléphone et t'aide à rester concentré, motivé et organisé au quotidien.

L'expérience est entièrement centrée sur le **chat**. Tu parles à ton compagnon (par défaut "Kai") comme tu parlerais à un ami ou un coach. Il te connaît, il se souvient de tes objectifs, de tes habitudes, de ce qui te bloque.

## Comment ça marche

### 1. Onboarding personnalisé (style Replika)
Quand tu ouvres Focus pour la première fois, tu passes par un onboarding de 13 étapes inspiré de Replika :
- Tu donnes ton prénom, ton âge, tes pronoms
- Tu décris tes objectifs de bien-être, ce que tu veux améliorer dans ta vie
- Tu personnalises ton compagnon : choix d'avatar 3D, nom, personnalité
- Le compagnon est "créé" avec une animation de chargement

Résultat : chaque compagnon est unique et personnalisé pour l'utilisateur.

### 2. Chat intelligent (écran principal)
L'app n'a qu'un seul écran : le chat avec ton compagnon.

- **Avatar 3D animé** (Ready Player Me) qui réagit en temps réel
- **Mode Home** : l'avatar est affiché en grand avec une barre de saisie en bas — pour les moments calmes
- **Mode Conversation** : les messages défilent avec l'avatar en fond — quand la discussion est active

Tu peux :
- Parler de ta journée, demander de l'aide pour organiser tes tâches
- Envoyer des messages vocaux (transcription automatique)
- Lancer un **appel vocal en direct** (comme FaceTime) — conversation naturelle avec le compagnon via IA vocale

Le compagnon utilise un thread persistant (Backboard) — il se souvient de tout, contexte inclus.

### 3. Appel vocal (LiveKit)
Tu peux appeler ton compagnon comme un vrai appel FaceTime :
- Écran noir minimaliste avec visualisation audio
- Le compagnon parle en temps réel avec une voix naturelle
- Il peut t'aider à planifier ta journée, te motiver, ou juste discuter
- Transcript disponible après l'appel

### 4. Focus Pulse (carte sociale)
Une carte interactive (MapKit) qui montre les utilisateurs à proximité qui sont en session de focus :
- Profils style Snapchat avec stats (temps de focus, streak)
- Tu peux encourager les autres utilisateurs
- Bouton "Rejoindre le focus" pour démarrer ta propre session
- Effet de motivation sociale : voir les autres bosser te pousse à bosser

### 5. App Blocking (ScreenTime API)
Focus peut bloquer les apps distrayantes pendant tes sessions :
- Utilise Family Controls / Screen Time d'Apple
- Configurable depuis les settings
- Se déclenche automatiquement pendant les sessions de focus

### 6. Widgets & Live Activities
- Widget sur l'écran d'accueil avec tes objectifs hebdomadaires
- Live Activity sur l'écran de verrouillage pendant les sessions (timer countdown)

## Modèle économique

Abonnement freemium avec deux tiers :

| | Gratuit | Focus Plus | Focus Max |
|---|---------|-----------|-----------|
| Chat avec compagnon | Limité | Illimité | Illimité |
| Sessions Focus | 3/jour | Illimitées | Illimitées |
| App Blocking | Basique | Avancé | Avancé |
| Appels vocaux | — | Limités | Illimités |
| Accès prioritaire | — | — | Oui |

Paiement via StoreKit 2 (Apple) + RevenueCat pour la gestion backend.

## Stack technique

### iOS (Swift / SwiftUI)
- **Architecture** : MVVM + Services avec état centralisé (singleton `FocusAppStore`)
- **UI** : SwiftUI natif, design inspiré de Replika (gradients bleus, dark mode)
- **Avatar** : Ready Player Me via WKWebView
- **Voix** : LiveKit (appels temps réel), Whisper (transcription)
- **IA** : Backend custom avec thread Backboard persistant (mémoire longue)
- **Maps** : MapKit natif
- **Notifications** : Firebase Cloud Messaging
- **Blocage d'apps** : Family Controls / Screen Time API
- **Paiements** : StoreKit 2 + RevenueCat
- **Déploiement** : Fastlane (TestFlight + App Store)

### Web (Next.js)
- Mirror simplifié de l'app iOS
- Même thread Backboard partagé (conversation synchro entre iOS et web)
- Stack : Next.js + React + TypeScript + TailwindCSS

### Backend
- API REST custom
- Thread de conversation persistant (Backboard) avec mémoire longue
- Endpoints pour : auth, chat, voice, sessions, discover, subscriptions
- WebSocket pour real-time (discover map)

## Positionnement

Focus n'est pas un timer de plus. C'est le croisement entre :
- **Replika** (compagnon IA personnalisé, avatar, lien émotionnel)
- **Forest/Be Focused** (sessions de concentration, streaks)
- **Snapchat Maps** (dimension sociale, voir ses amis en temps réel)

La différence clé : au lieu de te donner un outil passif, Focus te donne un **partenaire actif** qui s'adapte à toi, qui te relance quand tu procrastines, et qui rend la productivité sociale et engageante.

## Cible

- Étudiants (18-25 ans) qui veulent être plus productifs mais trouvent les apps classiques ennuyeuses
- Jeunes professionnels (25-35 ans) qui cherchent un cadre de productivité sans la rigidité d'un Notion
- Toute personne qui a besoin de motivation externe et de responsabilisation

## Métriques clés

- **Rétention J7/J30** : est-ce que les gens reviennent parler à leur compagnon ?
- **Sessions de focus par utilisateur** : est-ce que le compagnon les pousse à bosser ?
- **Durée moyenne de conversation** : est-ce que le lien émotionnel se crée ?
- **Conversion freemium → payant** : est-ce que la valeur perçue justifie l'abonnement ?

## Langues

L'app est disponible en 3 langues : **Français**, **Anglais**, **Espagnol**.
