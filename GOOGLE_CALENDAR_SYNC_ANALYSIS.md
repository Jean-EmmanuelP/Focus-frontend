# Analyse Complète - Synchronisation Google Calendar

## Architecture Actuelle

### Base de données

**1. `google_calendar_config`**
- Stocke les tokens OAuth (access_token, refresh_token, token_expiry)
- Configuration: is_enabled, sync_direction (bidirectional/to_google/from_google)
- Tracking: last_sync_at, last_routine_sync_at
- Calendar: calendar_id ('primary'), timezone, google_email

**2. `tasks`**
- Champs Google Calendar: google_event_id, google_calendar_id, last_synced_at
- Ces champs trackent l'état de sync bidirectionnelle

**3. `routine_google_events`**
- Tracking séparé pour les events de routine (PAS dans la table tasks)
- Primary key: (routine_id, event_date)
- Les routines créent 7 events quotidiens (pas de règle de récurrence)

---

## Flux de Synchronisation

### VERS Google Calendar (Focus → Google)

#### Tasks
| Action | Déclencheur | Implémentation |
|--------|-------------|----------------|
| Création | POST /calendar/tasks | Async goroutine → SyncTaskToGoogleCalendar() |
| Mise à jour | PATCH /calendar/tasks/{id} | Async goroutine → SyncTaskToGoogleCalendar() |
| Suppression | DELETE /calendar/tasks/{id} | Async goroutine → DeleteGoogleCalendarEvent() |

#### Routines
| Action | Déclencheur | Implémentation |
|--------|-------------|----------------|
| Création | POST /routines | Async → crée 7 events pour les 7 prochains jours |
| Mise à jour | PATCH /routines/{id} | Async → met à jour + crée les events manquants |
| Suppression | DELETE /routines/{id} | Async → supprime tous les events de routine_google_events |

**Particularités des routines:**
- Préfixe "🔄 " ajouté au titre
- Events créés pour today + 6 jours
- Re-sync automatique après 6 jours (checkWeeklySync)

### DEPUIS Google Calendar (Google → Focus)

**Déclencheur:** POST /google-calendar/sync → performSync()

**Logique d'import:**
1. Fetch events des 30 prochains jours (max 100 events)
2. Pour chaque event:
   - Skip si summary vide
   - Skip si commence par "🔄" (nos propres routines)
   - Si status="cancelled" → supprimer la task correspondante
   - Si event est une routine (dans routine_google_events) → update routine title
   - Si event existe déjà (par google_event_id) → update si Google plus récent
   - Sinon → créer nouvelle task

---

## Cas Gérés ✅

| Scénario | Direction | Statut |
|----------|-----------|--------|
| Créer task dans Focus | → Google | ✅ Auto |
| Modifier task dans Focus | → Google | ✅ Auto |
| Supprimer task dans Focus | → Google | ✅ Auto |
| Créer routine dans Focus | → Google (7 events) | ✅ Auto |
| Modifier routine dans Focus | → Google | ✅ Auto |
| Supprimer routine dans Focus | → Google | ✅ Auto |
| Créer event dans Google | → Focus (task) | ✅ Sur sync |
| Modifier event dans Google | → Focus | ✅ Si plus récent |
| Supprimer event dans Google | → Focus | ✅ Sur sync |
| Event all-day Google | → Focus | ✅ Parse date sans heure |
| Task sans scheduled_start | → Google | ✅ Défaut 09:00-10:00 |
| Conflit de timestamp | Bidirectionnel | ✅ Google gagne si plus récent |
| Routine event importé | Ignoré | ✅ Détecté par préfixe 🔄 |

---

## 🔴 PROBLÈMES CRITIQUES

### 1. Token Refresh NON Implémenté
**Fichier:** `googlecalendar/handler.go`

Le token OAuth expire après ~1 heure. Aucun mécanisme de refresh :
- `SaveTokens` calcule token_expiry mais ne le vérifie jamais
- Les opérations de sync échoueront silencieusement après expiration
- **Impact:** Sync arrête de fonctionner après 1h sans que l'utilisateur le sache

**Solution requise:**
```go
func (h *Handler) ensureValidToken(ctx context.Context, userID string) error {
    // Check if token expired
    // If expired, use refresh_token to get new access_token
    // Update DB with new tokens
}
```

### 2. checkWeeklySync Jamais Appelé
**Fichier:** `GoogleCalendarService.swift`

La méthode existe mais n'est jamais invoquée :
- Les routine events expirent après 7 jours
- Sans re-sync, les routines disparaissent de Google Calendar
- **Impact:** Perte de visibilité des routines dans Google Calendar

**Solution:** Appeler `checkWeeklySync()` au lancement de l'app

### 3. Erreurs Async Non Reportées
Toutes les opérations sync sont en goroutines :
- Les erreurs sont loggées mais jamais retournées au client
- L'utilisateur ne sait pas si la sync a échoué
- **Impact:** Perte de données silencieuse

---

## 🟡 PROBLÈMES IMPORTANTS

### 4. Pas de Pagination pour Import
- `maxResults=100` en dur
- Si l'utilisateur a >100 events en 30 jours, certains sont ignorés
- **Impact:** Calendriers chargés ne sync pas complètement

### 5. Accumulation d'Events Routine
- Les anciens events routine sont supprimés uniquement lors de `SyncAllRoutinesToGoogleCalendar`
- Une update unique de routine ne nettoie pas les anciens events
- **Impact:** Events obsolètes restent dans Google Calendar

### 6. Gestion Timezone Incomplète
- Utilise config.Timezone (défaut: Europe/Paris)
- Ne vérifie pas si le timezone est valide
- Si l'utilisateur change de timezone système, les events restent dans l'ancien
- **Impact:** Décalages horaires

### 7. Tasks Privées Synchronisées
- Le champ `is_private` existe sur les tasks
- Mais la sync ne vérifie pas ce champ
- **Impact:** Tasks privées visibles dans Google Calendar

---

## 🟠 PROBLÈMES MODÉRÉS

### 8. Pas de Retry Logic
- Un seul appel API qui échoue = sync échouée
- Pas de backoff exponentiel
- **Impact:** Erreurs réseau causent perte de données

### 9. Race Condition Possible
- Si création task + import Google en parallèle
- Pourrait créer des doublons (risque faible grâce à google_event_id)

### 10. Pas de Sync Tokens Google
- Toujours fetch les 30 derniers jours complets
- Pas de mécanisme de sync incrémentale
- **Impact:** Inefficace pour gros calendriers

### 11. Pas de Push Notifications
- Sync uniquement par polling
- Pas de webhook Google Calendar
- Les changements nécessitent sync manuelle

---

## Fonctionnalités Manquantes

1. **Refresh Token Automatique** - CRITIQUE
2. **Sync sélective** (filtrer par calendrier/type)
3. **Import de routines** (Google → Focus routine)
4. **Sélection de calendrier** (autre que "primary")
5. **Notifications de résultat sync**
6. **Retry avec backoff exponentiel**
7. **Sync tokens pour incremental sync**
8. **Webhook pour real-time sync**

---

## Fichiers Clés

| Fichier | Responsabilité |
|---------|----------------|
| `backend/internal/googlecalendar/handler.go` | Toute la logique sync (1429 lignes) |
| `backend/internal/calendar/handler.go` | Handlers tasks avec appels sync |
| `backend/internal/routines/handler.go` | Handlers routines avec appels sync |
| `iOS/Services/GoogleCalendarService.swift` | Service frontend |
| `iOS/Views/Settings/GoogleCalendarSettingsView.swift` | UI settings |
| `backend/migrations/migrations.sql` | Schema DB |

---

## Priorités de Fix

1. **🔴 P0:** Implémenter token refresh
2. **🔴 P0:** Appeler checkWeeklySync au lancement app
3. **🟡 P1:** Ajouter pagination pour import (>100 events)
4. **🟡 P1:** Reporter les erreurs de sync à l'utilisateur
5. **🟡 P2:** Exclure tasks privées de la sync
6. **🟠 P3:** Ajouter retry logic
7. **🟠 P3:** Implémenter sync tokens
