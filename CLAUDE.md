# Focus App - Documentation Claude

## Vue d'ensemble de l'application

**Focus** est une application iOS de productivité et de suivi d'habitudes conçue pour aider les utilisateurs à gérer leur temps, développer leur concentration et atteindre leurs objectifs à travers des sessions de focus guidées, des rituels quotidiens et une responsabilisation communautaire.

---

## Fonctionnalités principales

### 1. FireMode - Sessions de Focus
- Sessions avec timer (25, 50, 90 minutes ou personnalisé)
- Liaison avec des Quests (objectifs)
- Blocage d'apps via ScreenTime
- Live Activities sur l'écran de verrouillage
- Widget de compte à rebours
- Journalisation manuelle de sessions

### 2. Calendrier & Planification de tâches
- Planification de journée avec prompts personnalisés et suggestions IA
- Gestion de tâches avec blocs horaires (matin, après-midi, soir)
- Priorités, durées estimées, association aux Quests
- Intégration Google Calendar
- Vue semaine visuelle

### 3. Rituels quotidiens
- Création de routines quotidiennes/hebdomadaires
- Suivi de complétion dans le dashboard
- Planification horaire
- Catégorisation par domaine de vie

### 4. Quests (Objectifs)
- Suivi multi-domaines : Santé, Apprentissage, Carrière, Relations, Créativité, Autre
- Barres de progression visuelles
- Gestion de statut : actif, complété, en pause, archivé
- Dates cibles optionnelles

### 5. Check-ins quotidiens
- **Morning Check-in** : humeur matinale, qualité de sommeil, intentions quotidiennes
- **Evening Review** : rituels complétés, plus grande victoire, bloqueurs, objectif de demain

### 6. Dashboard & Analytics
- Suivi de streak avec niveaux de flamme
- Stats hebdomadaires (graphique de minutes par jour)
- Pourcentage de complétion tâches/rituels
- CTA adaptatif (Start Day → End of Day → Completed)

### 7. Crew & Communauté
- Gestion d'équipe avec demandes d'amis
- Leaderboard de comparaison
- Groupes de crew avec routines partagées
- Feed communautaire avec photos et likes
- WebSocket pour mises à jour temps réel

### 8. Journal
- Suivi d'humeur (score 1-5)
- Analyse de sentiment
- Streak de journalisation

### 9. Profil & Abonnement
- Personnalisation du profil
- Préférence de pic de productivité
- Intégration RevenueCat pour abonnements Pro

---

## Architecture

```
Focus/
├── App/FocusApp.swift              # Point d'entrée + deep linking
├── Core/
│   ├── AppStore.swift              # État centralisé (singleton)
│   ├── APIClient.swift             # Gestion HTTP
│   ├── FocusSessionActivity.swift  # Live Activities
│   └── SyncManager.swift           # Synchronisation données
├── Models/
│   ├── Models.swift                # Modèles domaine
│   └── CalendarModels.swift        # Modèles calendrier
├── ViewModels/                     # MVVM - Logique métier
├── Services/                       # Couche API/Services
├── Views/                          # Interface utilisateur
├── Navigation/                     # Router & navigation
└── DesignSystem/                   # Tokens & composants
```

**Pattern** : MVVM + Services avec état centralisé via `FocusAppStore.shared`

---

## Deep Linking existant

```swift
focus://firemode       → Lancer FireMode
focus://dashboard      → Aller au dashboard
focus://starttheday    → Lancer morning check-in
focus://endofday       → Lancer evening review
```

---

## État actuel des notifications

```swift
// Dans AppConfiguration.swift
static let notificationsEnabled = false  // DÉSACTIVÉ - Prêt pour implémentation
```

**Systèmes existants :**
- Haptic feedback (vibrations sur événements)
- Live Activities (compte à rebours écran verrouillé)
- Widget (timer temps réel)
- Dialogues d'alerte (sessions stales, validation)

**Manquant :**
- Push notifications
- Notifications locales programmées
- Rappels basés sur l'heure
- Alertes déclenchées par événements

---

## Propositions de notifications à implémenter

### Priorité 1 - Notifications essentielles (Core Experience)

| Catégorie | Notification | Déclencheur | Deep Link |
|-----------|-------------|-------------|-----------|
| **Focus** | "Session terminée ! 🎉 Tu as focus [X] minutes" | Fin de session | `focus://dashboard` |
| **Focus** | "Plus que 5 minutes de focus !" | 5 min avant fin | - |
| **Rituel** | "C'est l'heure de [Nom du rituel] 🌅" | Heure programmée | `focus://dashboard` |
| **Check-in** | "Bonjour ! Planifie ta journée ☀️" | 7h-8h (configurable) | `focus://starttheday` |
| **Check-in** | "Comment s'est passée ta journée ? 🌙" | 21h (configurable) | `focus://endofday` |

### Priorité 2 - Notifications de motivation (Engagement)

| Catégorie | Notification | Déclencheur | Deep Link |
|-----------|-------------|-------------|-----------|
| **Streak** | "🔥 [X] jours de streak ! Continue !" | Milestone (7, 14, 30, 60, 90) | `focus://dashboard` |
| **Streak** | "⚠️ Ta streak est en danger ! Focus aujourd'hui" | Fin de journée sans session | `focus://firemode` |
| **Quest** | "📈 Quest '[Titre]' à 50% !" | Milestone progression | `focus://quests` |
| **Quest** | "🎯 Quest '[Titre]' complétée !" | Complétion | `focus://quests` |
| **Accountability** | "✅ Journée validée ! Tu as atteint tes objectifs" | Validation quotidienne | `focus://dashboard` |

### Priorité 3 - Notifications sociales (Community)

| Catégorie | Notification | Déclencheur | Deep Link |
|-----------|-------------|-------------|-----------|
| **Crew** | "[Nom] veut rejoindre ton crew ! 👥" | Demande d'ami reçue | `focus://crew` |
| **Crew** | "Tu as été invité au groupe [Nom] !" | Invitation groupe | `focus://crew` |
| **Leaderboard** | "📈 Tu as gagné [X] places au classement !" | Changement de rang | `focus://leaderboard` |
| **Crew** | "[Nom] vient de terminer une session focus 🔥" | Session terminée par ami | `focus://crew` |

### Priorité 4 - Notifications de rappel (Reminders)

| Catégorie | Notification | Déclencheur | Deep Link |
|-----------|-------------|-------------|-----------|
| **Rituel** | "Tu as oublié [Rituel] aujourd'hui" | Rituel non complété avant fin de journée | `focus://dashboard` |
| **Tâche** | "Rappel : [Tâche] prévue à [Heure]" | 15-30 min avant tâche | `focus://calendar` |
| **Quest** | "⏰ Deadline dans 3 jours pour [Quest]" | 3 jours avant target_date | `focus://quests` |
| **Journal** | "📔 Prends un moment pour journaliser" | Rappel quotidien (configurable) | `focus://journal` |

---

## Plan d'implémentation technique

### Phase 1 : Infrastructure
1. Créer `NotificationService.swift`
2. Demander les permissions (`UNUserNotificationCenter`)
3. Configurer les catégories et actions
4. Activer `AppConfiguration.notificationsEnabled`

### Phase 2 : Notifications locales
1. Implémenter les rappels morning/evening check-in
2. Implémenter les rappels de rituels programmés
3. Implémenter les alertes de streak en danger

### Phase 3 : Notifications push (backend requis)
1. Configurer APNs sur le backend
2. Enregistrer le device token
3. Implémenter les notifications sociales (crew, leaderboard)
4. Implémenter les célébrations de milestone

### Phase 4 : Paramètres utilisateur
1. Créer `NotificationSettingsView`
2. Permettre de configurer les heures de rappel
3. Permettre d'activer/désactiver par catégorie
4. Respecter le mode "Ne pas déranger"

---

## Fichiers à créer/modifier

```
Focus/
├── Services/
│   └── NotificationService.swift     # NOUVEAU - Service principal
├── ViewModels/
│   └── NotificationSettingsViewModel.swift  # NOUVEAU
├── Views/
│   └── Settings/
│       └── NotificationSettingsView.swift   # NOUVEAU
├── Core/
│   └── AppConfiguration.swift        # MODIFIER - Activer flag
└── App/
    └── FocusApp.swift                # MODIFIER - Initialisation
```

---

## Dépendances

- `UserNotifications` (framework natif iOS)
- Aucune librairie tierce nécessaire pour les notifications locales
- Pour push : configuration APNs côté backend

---

## Notes importantes

1. **Respecter la vie privée** : Ne pas envoyer de notifications avec contenu sensible sur l'écran de verrouillage
2. **Fréquence raisonnable** : Éviter le spam, maximum 3-5 notifications par jour
3. **Personnalisation** : Laisser l'utilisateur contrôler chaque type de notification
4. **Deep links** : Utiliser le système existant pour la navigation depuis les notifications
5. **Badge app** : Mettre à jour le badge avec le nombre de tâches/rituels en attente
