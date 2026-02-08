# Focus App - État des Lieux Complet

> Dernière mise à jour : 7 février 2026 - 18h00

---

## 1. PARAMÈTRES (Settings)

### ✅ CONNECTÉ AU BACKEND

| Paramètre | Frontend | Backend | Status |
|-----------|----------|---------|--------|
| **Nom (firstName)** | `updateName()` | `PATCH /me` → `first_name` | ✅ Fonctionnel |
| **Pronoms (gender)** | `updatePronouns()` | `PATCH /me` → `gender` | ✅ Fonctionnel |
| **Notifications** | `saveNotificationSettings()` | `PATCH /me` → `notifications_enabled` | ✅ Fonctionnel |
| **Supprimer compte** | `deleteAccount()` | `DELETE /me` | ✅ Fonctionnel |
| **Déconnexion** | `FocusAppStore.shared.signOut()` | Supabase Auth | ✅ Fonctionnel |
| **Date de naissance** | `updateBirthday()` | `PATCH /me` → `birthday` | ✅ Fonctionnel |
| **Companion Name** | `saveCompanionSettings()` | `PATCH /me` → `companion_name` | ✅ Fonctionnel |
| **Companion Gender** | `saveCompanionSettings()` | `PATCH /me` → `companion_gender` | ✅ Fonctionnel |

### 🔴 BUGS D'AFFICHAGE (Code fait mais affichage cassé)

| Bug | Fichier:Ligne | Problème | Fix |
|-----|---------------|----------|-----|
| **Anniversaire affiche "Non défini"** | `ReplicaSettingsView.swift:680` | Affiche "Non défini" en dur au lieu de `store.user?.birthday` | Formater et afficher la date |

### ❌ NON CONNECTÉ (À IMPLÉMENTER)

| Paramètre | Problème | Solution |
|-----------|----------|----------|
| **Changer l'email** | `// TODO` (ligne 172) | Utiliser Supabase Auth `updateUser()` |
| **Changer mot de passe** | Action vide `{}` (ligne 700) | Utiliser Supabase Auth `updateUser()` |
| **Avatar hérité** | `@State` local uniquement | Backend pas nécessaire - garder en local |
| **Afficher Focus dans chat** | `@State` local uniquement | Backend pas nécessaire - garder en local |
| **Mode selfie vidéo** | `@State` local uniquement | Backend pas nécessaire - garder en local |
| **Afficher le niveau** | `@State` local uniquement | Backend pas nécessaire - garder en local |
| **Musique de fond** | `@State` local uniquement | Backend pas nécessaire - garder en local |
| **Sons** | `@State` local uniquement | Backend pas nécessaire - garder en local |
| **Face ID** | `@State` local uniquement | Stocker en Keychain local |

---

## 2. VALEURS HARDCODÉES "Kai" (À CORRIGER)

> Le nom du companion doit être dynamique (`store.user?.companionName ?? "Kai"`)

| Fichier | Ligne | Code actuel | Fix requis |
|---------|-------|-------------|------------|
| `ChatModels.swift` | 135 | `static let name = "Kai"` | Passer en paramètre |
| `Navigation.swift` | 16 | `case .chat: return "Kai"` | Utiliser `store.user?.companionName` |
| `KaiProfileView.swift` | 296 | `Text("Kai")` | Utiliser `companionName` dynamique |

### ✅ Déjà corrigés

| Fichier | Status |
|---------|--------|
| `ChatView.swift:28` | ✅ `store.user?.companionName ?? "Kai"` |
| `CompanionProfileView.swift:15` | ✅ `store.user?.companionName ?? "Kai"` |
| `ReplicaSettingsView.swift:31` | ✅ `store.user?.companionName ?? "Kai"` |
| `FocusPaywallView.swift` | ✅ Reçoit `companionName` en paramètre |
| `NewOnboardingView.swift` | ✅ Utilise la saisie utilisateur |

---

## 3. PAYWALLS - TOUS CONNECTÉS À REVENUECAT ✅

| Paywall | Fichier | Packages | Status |
|---------|---------|----------|--------|
| **FocusPaywallView** | `FocusPaywallView.swift` | Plus (monthly), Max (premium) | ✅ RevenueCat |
| **RevenueCatNativePaywall** | `RevenueCatPaywallView.swift` | Automatique | ✅ RevenueCat |

### ✅ Paywalls supprimés (étaient en dur)

| Ancien paywall | Fichier | Prix en dur | Status |
|----------------|---------|-------------|--------|
| ~~ReplicaPaywallView~~ | `CompanionProfileView.swift` | 59,99€, 67,99€, 52,99€ | ✅ SUPPRIMÉ |
| ~~ReplicaSubscriptionView~~ | `ReplicaSettingsView.swift` | 5,67€, 5,00€, 4,42€/mois | ✅ SUPPRIMÉ |

---

## 4. REVENUCAT CONFIGURATION

| Élément | Valeur | Status |
|---------|--------|--------|
| **API Key** | `appl_YgMmJqvIqMgLEKzriMHnHGXILMu` | ✅ Configuré |
| **Entitlement** | `"Volta Pro"` | ✅ |
| **Package Plus** | `"monthly"` (34,99€/mois) | ⚠️ À créer dans App Store Connect |
| **Package Max** | `"premium"` (129,99€/mois) | ⚠️ À créer dans App Store Connect |

---

## 2. ONBOARDING

### ✅ FAIT

| Étape | Description | Status |
|-------|-------------|--------|
| Welcome | Écran d'accueil | ✅ |
| Prenom | Saisie prénom | ✅ |
| Age | Saisie âge (roue) | ✅ |
| Gender | Choix pronoms | ✅ |
| LifeArea | Domaine de vie | ✅ |
| Challenges | Défis actuels | ✅ |
| Goals | Objectifs | ✅ |
| CompanionName | Nommer le companion | ✅ |
| CompanionGender | Genre du companion | ✅ |
| AvatarStyle | Style d'avatar | ✅ |
| MoreAboutYou | Gmail + Location | ✅ UI créé |
| Loading | Animation chargement | ✅ |
| Paywall | Abonnement | ✅ UI créé |
| MeetCompanion | Rencontre companion | ✅ |

### ❌ À VÉRIFIER/CORRIGER

| Problème | Détails |
|----------|---------|
| **Gmail OAuth** | Bouton créé mais à tester en conditions réelles |
| **Location** | Permission demandée mais données pas envoyées au backend |
| **Sauvegarde étapes** | Vérifier que chaque étape sauvegarde bien dans `user_onboarding.responses` |
| **Companion name** | Vérifier qu'il est bien sauvegardé dans `users.companion_name` |

---

## 3. PAYWALL / ABONNEMENT

### ✅ FAIT

| Élément | Status |
|---------|--------|
| `FocusPaywallView` (style Replika) | ✅ Créé |
| `RevenueCatManager` | ✅ Intégré |
| Prix dynamiques (pas hardcodés) | ✅ Corrigé |
| Plans Plus/Max | ✅ UI créé |
| Bouton achat | ✅ Connecté à RevenueCat |
| Restaurer achats | ✅ Fonctionnel |

### ❌ À FAIRE

| Tâche | Priorité |
|-------|----------|
| **Configurer RevenueCat** | 🔴 HAUTE - En attente de ta config |
| **Créer produits App Store Connect** | 🔴 HAUTE |
| **Feature Gating** | 🔴 HAUTE - Bloquer fonctionnalités pour gratuits |
| **Avatar dans paywall** | 🟡 MOYENNE - Actuellement placeholder |

---

## 4. SPLASH SCREEN

### ✅ FAIT

| Élément | Status |
|---------|--------|
| Animation abstraite (3 blobs) | ✅ Créé |
| Rotation + Scale | ✅ |
| Transition hypnotique | ✅ |
| Suppression "FOCUS ON THE MISSION" | ✅ |

---

## 5. CHAT AVEC COMPANION

### ✅ FAIT

| Fonctionnalité | Status |
|----------------|--------|
| Messages texte | ✅ |
| Messages vocaux | ✅ |
| Mémoire sémantique (Mira-style) | ✅ |
| Extraction de faits | ✅ |
| Embeddings vectoriels | ✅ |
| Persona depuis Gmail | ✅ Backend prêt |
| Historique conversation | ✅ |
| Nom dynamique dans ChatView | ✅ |
| Nom dynamique dans CompanionProfileView | ✅ |
| Timer memory leak fix | ✅ |

### ❌ À CORRIGER

| Problème | Fichier:Ligne | Fix |
|----------|---------------|-----|
| **Hardcoded "Kai" dans CoachPersona** | `ChatModels.swift:135` | Passer companionName en paramètre |
| **Hardcoded "Kai" dans Navigation** | `Navigation.swift:16` | Utiliser store.user?.companionName |
| **Hardcoded "Kai" dans KaiProfileView** | `KaiProfileView.swift:296` | Utiliser store.user?.companionName |
| **Voice recording Pro only** | - | Vérifier feature gating |

---

## 6. BACKEND

### ✅ ENDPOINTS EXISTANTS

```
POST /chat/message          ✅
POST /chat/voice            ✅
GET  /chat/history          ✅
DELETE /chat/history        ✅

GET  /me                    ✅
PATCH /me                   ✅
DELETE /me                  ✅
POST /me/avatar             ✅
DELETE /me/avatar           ✅
POST /me/location           ✅

GET  /calendar/tasks        ✅
POST /calendar/tasks        ✅
PATCH /calendar/tasks/{id}  ✅
...

GET  /gmail/config          ✅
POST /gmail/tokens          ✅
POST /gmail/analyze         ✅
DELETE /gmail/config        ✅

GET  /onboarding/status     ✅
PUT  /onboarding/progress   ✅
POST /onboarding/complete   ✅
```

### ❌ MANQUANT AU BACKEND

| Endpoint/Champ | Besoin |
|----------------|--------|
| `users.birthday` | Colonne DATE pour date de naissance |
| `users.companion_name` | ⚠️ Vérifier si existe |
| `users.companion_gender` | ⚠️ Vérifier si existe |
| `users.avatar_style` | ⚠️ Vérifier si existe |
| Préférences UI | Colonnes pour toggles (sounds, music, etc.) |

---

## 7. BASE DE DONNÉES

### ✅ COLONNES EXISTANTES (users)

```
id, email, full_name, avatar_url, created_at
pseudo, first_name, last_name, gender, age
description, hobbies, life_goal, day_visibility
productivity_peak, language, timezone
notifications_enabled, morning_reminder_time
latitude, longitude, city, country, neighborhood, location_updated_at
work_place, companion_name, companion_gender, avatar_style
```

### ❌ COLONNES À AJOUTER (users)

```sql
-- Date de naissance (pour les paramètres)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS birthday DATE;

-- Préférences UI (optionnel - peut rester en local)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS sounds_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS background_music BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS show_level BOOLEAN DEFAULT false;
```

---

## 8. FEATURE GATING (Gratuits vs Pro)

### ❌ À IMPLÉMENTER

| Fonctionnalité | Gratuit | Pro |
|----------------|---------|-----|
| Messages texte/jour | 10 ? | Illimité |
| Messages vocaux | ❌ Bloqué | ✅ |
| Génération images | ❌ | ✅ |
| Mémoire sémantique | Basique ? | Complète |
| Appels vidéo | ❌ | ✅ (Max only) |

**Action requise** : Définir exactement ce qui est gratuit vs payant

---

## 9. NOTIFICATIONS PUSH

### ✅ FAIT

| Élément | Status |
|---------|--------|
| `NotificationService.swift` | ✅ Créé |
| Backend endpoints | ✅ `/notifications/*` |
| Firebase setup | ⚠️ À vérifier |

### ❌ À FAIRE

| Tâche | Priorité |
|-------|----------|
| Activer dans `AppConfiguration` | 🟡 |
| Tester réception | 🟡 |
| Notifications locales (rappels) | 🟡 |

---

## 10. LIENS & URLs

### ❌ À METTRE À JOUR

| Lien | Valeur actuelle | Action |
|------|-----------------|--------|
| Centre d'aide | `https://firelevel.app/help` | Créer la page |
| Évaluez-nous | `https://apps.apple.com/app/id123456789` | Mettre vrai ID |
| Conditions | `https://firelevel.app/terms` | Créer la page |
| Confidentialité | `https://firelevel.app/privacy` | Créer la page |
| Reddit | `https://reddit.com/r/focus` | Créer le subreddit |
| Discord | `https://discord.gg/focus` | Créer le serveur |
| Facebook | `https://facebook.com/focusapp` | Créer la page |

---

## PRIORITÉS D'IMPLÉMENTATION

### 🔴 URGENTS (Avant release)

1. [ ] **Corriger affichage anniversaire** - Affiche "Non défini" au lieu de la date
2. [ ] **Corriger hardcoded "Kai"** - 3 fichiers à corriger
3. [ ] Configurer RevenueCat (produits + prix dans App Store Connect)
4. [ ] Tester onboarding complet (nouveau user)
5. [ ] Feature gating basique (bloquer fonctionnalités gratuits)

### 🟡 IMPORTANTS (Semaine prochaine)

6. [ ] Connecter changement email (Supabase Auth)
7. [ ] Connecter changement mot de passe (Supabase Auth)
8. [ ] Tester Gmail OAuth en conditions réelles
9. [ ] Créer pages légales (CGU, Privacy, Conditions)

### 🟢 NICE TO HAVE (Plus tard)

10. [ ] Avatar réel dans paywall (actuellement placeholder)
11. [ ] Créer communautés sociales (Reddit, Discord, Facebook)
12. [ ] Diviser gros fichiers (AppStore.swift, ReplicaSettingsView.swift)

---

## COMMANDES UTILES

```bash
# Vérifier colonnes users
PGPASSWORD="ydduQOwjQ1ArOlMs" psql "postgresql://postgres:ydduQOwjQ1ArOlMs@db.zawilkajkkndcmdvmffo.supabase.co:5432/postgres" -c "\d public.users"

# Build iOS
xcodebuild -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' build

# Deploy TestFlight
cd /Users/jperrama/Developer/iOS_Swift_Applications/Focus && fastlane beta
```

---

## 11. CODE REVIEW - MAINTENABILITÉ

> Analyse effectuée le 7 février 2026

### 🔴 CRITIQUES (À corriger)

| Problème | Fichier | Impact |
|----------|---------|--------|
| **God Object** | `AppStore.swift` (1,445 lignes) | Gère 10+ responsabilités (auth, rituals, sessions, widgets, goals). Rend les tests et la maintenance très difficiles |
| **Accès direct au singleton** | Multiple fichiers utilisent `FocusAppStore.shared` | Viole l'injection de dépendances, rend les tests unitaires impossibles |
| ~~**Memory leak Timer**~~ | ~~`ChatView.swift:577`~~ | ✅ CORRIGÉ - Timer invalidé dans `onDisappear` |

### 🟡 MAJEURS (À améliorer)

| Problème | Fichier | Recommandation |
|----------|---------|----------------|
| Instanciation de services dupliquée | `APIServices.swift` - 15+ services | Utiliser classe de base ou injection |
| Strings hardcodées en français | `CompanionProfileView.swift`, `ReplicaSettingsView.swift` | Extraire vers fichiers de localisation |
| Fichiers de vue massifs | `ReplicaSettingsView.swift` (1,650 lignes) | Diviser en fichiers séparés |
| Gestion d'erreurs silencieuse | `print("Failed to...")` sans feedback UI | Afficher alertes utilisateur |
| Services instanciés dans les vues | Vues créent `UserService()` directement | Déplacer vers ViewModels |
| Duplication d'état redondante | `DashboardViewModel` duplique l'état de AppStore | Utiliser computed properties |

### ✅ POINTS POSITIFS

| Élément | Détails |
|---------|---------|
| `@MainActor` bien utilisé | Toutes les ViewModels et services annotés |
| Logging API complet | `APILogger` avec timing, JSON formaté, masquage données sensibles |
| Endpoints typés | `Endpoint` enum avec type-safety |
| Erreurs bien définies | `APIError` enum avec `LocalizedError` |
| Updates optimistes | Rollback sur erreur dans `DashboardViewModel` |

### 📋 PLAN D'ACTION TECHNIQUE

1. **Immédiat** : ~~Corriger memory leak timer~~ ✅ Fait
2. **Court terme** : Diviser `FocusAppStore` en managers spécialisés
3. **Moyen terme** : Extraire les strings pour localisation
4. **Moyen terme** : Diviser les gros fichiers de vues
5. **Long terme** : Implémenter injection de dépendances cohérente
