# SHIP.md — Ce qui manque pour shipper Focus comme Coach de Vie

> Dernière mise à jour : 2026-02-14

---

## BACKEND — Coach IA (Priorité 1)

### 1. Réécrire le System Prompt (CRITIQUE)
- **Fichier** : `Focus_backend/firelevel-backend/internal/chat/handler.go` (ligne 104)
- **Action** : Réécrire le prompt pour positionner comme un **coach exigeant mais bienveillant**
- [x] FAIT — Prompt réécrit : coach de vie, pas ami passif

### 2. Enrichir le contexte envoyé à l'IA (CRITIQUE)
- **Fichier** : `handler.go` — fonctions `getUserInfo()` et `generateResponse()`
- **Action** : Ajouter les requêtes SQL pour envoyer au coach :
  - [x] **Tâches du jour** (titres, horaires, statut) — table `tasks`
  - [x] **Routines du jour** (noms, complétées ou non) — tables `routines` + `routine_completions`
  - [x] **Quests actives** (titres, progression current/target) — table `quests`
  - [x] **Streak** (jours consécutifs) — depuis `users.current_streak`
  - [x] **Check-in matin** (statut) — table `daily_reflections`
  - [x] **Réflexion du soir** (biggest win, blockers, objectif demain) — table `daily_reflections`
  - [x] **Objectifs hebdomadaires** (titres, complétés ou non) — table `weekly_goals` + `weekly_goal_items`
  - [x] **Dernière humeur/journal** — table `journal_entries`

### 3. Augmenter le MaxOutputTokens
- [x] FAIT — Passé de 300 à 500 tokens

### 4. Nom du compagnon dynamique
- [x] FAIT — `companion_name` récupéré depuis la table `users` et injecté dans le prompt

### 5. Blocage/Déblocage d'apps via le coach
- [x] FAIT — Backend : instructions dans le prompt pour `block_now` et `unblock_now`
- [x] FAIT — Backend : parsing des actions `block_apps` et `unblock_apps`
- [x] FAIT — iOS : `ChatViewModel` gère les actions de blocage/déblocage
- [x] FAIT — iOS : Statut `apps_blocked` envoyé au backend pour contexte
- [x] FAIT — iOS : Confirmation "Es-tu sûr ?" pour déblocage manuel dans les paramètres
- [x] FAIT — Le coach refuse de débloquer sans bonne raison

### 6. Greetings coach côté iOS
- [x] FAIT — `CoachPersona` et `ChatViewModel` mis à jour avec des greetings de coach contextuel (streak, heure, bilan)

### 6b. Premier contact — Onboarding via le coach
- [x] FAIT — Détection "PREMIÈRE SÉANCE" dans le contexte (pas de données = nouvel utilisateur)
- [x] FAIT — Instructions dans le prompt pour guider le premier contact
- [x] FAIT — Greeting jour 1 : "C'est quoi le truc que tu veux vraiment changer dans ta vie ?"
- [x] FAIT — Fallback responses cohérentes (ton technique, pas psy)

---

## BACKEND — Actions du Coach (Priorité 2)

### 7. Le coach peut créer des quests
- [x] FAIT — `create_quest` dans le prompt + `createQuestFromChat()` avec area auto-détectée

### 8. Le coach peut créer des routines
- [x] FAIT — `create_routine` dans le prompt + `createRoutineFromChat()`

### 9. Streak basé sur l'engagement quotidien
- [x] FAIT — `updateStreak()` : streak monte si message envoyé, tâche complétée, routine complétée ou session focus
- [x] FAIT — `last_active_date` ajouté à la table `users`
- [x] FAIT — Appelé dans le chat handler à chaque message
- [x] FAIT — Package partagé `internal/streak` appelé dans focus, routines, calendar et chat handlers

### 10. Le coach peut modifier les quests
- [x] FAIT — `update_quest` dans le prompt + `updateQuestProgress()` avec matching fuzzy du titre

### 11. Le coach peut déclencher un check-in
- **Action** : Si l'utilisateur n'a pas fait son morning check-in, le coach peut l'initier dans le chat
- [ ] À faire

---

## FRONTEND iOS (Priorité 2)

### 10. Notifications locales
- [x] FAIT — `NotificationService.swift` existait déjà avec morning + task reminders
- [x] FAIT — Rappel morning check-in (configurable, défaut 8h)
- [x] FAIT — Rappel evening review (configurable, défaut 21h)
- [x] FAIT — Rappels de rituels (à l'heure programmée de chaque routine)
- [x] FAIT — Alerte streak en danger (quotidienne à 20h, annulée si actif)
- [x] FAIT — `NotificationSettingsView` mise à jour avec tous les toggles
- [x] FAIT — `AppConfiguration.notificationsEnabled` activé (`true`)

### 11. Pricing
- **Fichier** : `FocusPaywallView.swift`, `RevenueCatManager.swift`
- **Problème** : Focus Plus à €34.99/mois, Focus Max à €129.99/mois — trop cher pour lancer
- **Action** :
  - [ ] Revoir les tiers dans RevenueCat dashboard
  - [ ] Focus Pro : €9.99/mois (chat illimité, mémoire, voice, analytics)
  - [ ] Mettre à jour le paywall dans l'app
- [ ] À faire

### 12. Définir clairement free vs pro
- **Problème** : Pas de limite claire dans le code pour le tier gratuit
- **Action** :
  - [ ] Free : sessions focus illimitées, 3 rituels, check-ins, 5 messages/jour au coach
  - [ ] Pro : chat illimité, voice, mémoire complète, analytics avancés, routines illimitées
  - [ ] Implémenter le compteur de messages gratuits
- [ ] À faire

### 13. App Store Optimization
- **Action** :
  - [ ] 5-6 screenshots qui vendent le bénéfice
  - [ ] Titre ASO : "Focus — Coach IA & Productivité"
  - [ ] Description orientée problème/solution
  - [ ] Privacy Policy & Terms of Service
  - [ ] Catégorie : Productivity ou Health & Fitness
- [ ] À faire

---

## BACKEND — Améliorations Coach (Priorité 3)

### 14. Coach proactif
- **Action** : Endpoint pour générer un message proactif (appelé par les notifications)
  - Matin : "Salut ! Hier tu as focus X min. Tu as 3 tâches aujourd'hui : [liste]. On attaque ?"
  - Soir sans activité : "T'as pas encore focus aujourd'hui. Qu'est-ce qui bloque ?"
  - Milestone : "7 jours de streak ! Continue comme ça."
- [ ] À faire

### 15. Bilans hebdomadaires automatiques
- **Action** : Le coach génère un résumé de la semaine (minutes focus, tâches, routines, progression quests)
- [ ] À faire

### 16. Considérer le modèle IA
- **Problème** : Gemini 2.0 Flash est rapide mais basique pour du coaching nuancé
- **Action** : Tester Gemini Pro ou Claude pour les réponses de coaching (garder Flash pour transcription/extraction)
- [ ] À évaluer

---

## NICE TO HAVE (Post-launch)

### 17. Widget enrichi
- Le widget affiche non seulement le timer mais aussi les tâches du jour et le streak
- [ ] Plus tard

### 18. Partage social des achievements
- Partager ses milestones (streak, quests complétées) sur les réseaux
- [ ] Plus tard

### 19. Landing page
- Site web simple pour les campagnes pub
- [ ] Plus tard

### 20. Push notifications (backend)
- APNs pour notifications déclenchées côté serveur (social, milestones)
- [ ] Plus tard

---

## RÉSUMÉ DES PRIORITÉS

| # | Tâche | Statut | Impact |
|---|-------|--------|--------|
| 1 | Réécrire le system prompt coach | ✅ FAIT | 🔴 Critique |
| 2 | Enrichir le contexte IA (tâches, routines, quests, streak...) | ✅ FAIT | 🔴 Critique |
| 3 | Augmenter MaxOutputTokens (300→500) | ✅ FAIT | 🟡 Important |
| 4 | Nom compagnon dynamique | ✅ FAIT | 🟡 Important |
| 5 | Blocage/déblocage d'apps via le coach | ✅ FAIT | 🔴 Critique |
| 6 | Greetings coach iOS + premier contact | ✅ FAIT | 🔴 Critique |
| 7 | Coach crée des quests via le chat | ✅ FAIT | 🔴 Critique |
| 8 | Coach crée des routines via le chat | ✅ FAIT | 🔴 Critique |
| 9 | Streak basé sur engagement quotidien | ✅ FAIT | 🔴 Critique |
| 10-11 | Actions du coach (modifier quests, check-in) | ⬜ À faire | 🟡 Important |
| 12 | Notifications locales | ⬜ À faire | 🔴 Critique |
| 13 | Pricing | ⬜ À faire | 🔴 Critique |
| 14 | Free vs Pro | ⬜ À faire | 🟡 Important |
| 15 | ASO | ⬜ À faire | 🔴 Critique pour pub |
| 16-17 | Coach proactif + bilans | ⬜ À faire | 🟢 Nice to have |
