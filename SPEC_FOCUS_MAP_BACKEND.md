# Focus Map — Backend Spec

## Contexte

L'app iOS a une **Focus Map** : une carte mondiale qui montre l'activite de focus de la communaute en temps reel + un **classement par pays**. Le frontend iOS est deja implemente et attend un seul endpoint.

---

## Endpoint a creer

### `GET /focus-sessions/live-stats`

**Auth** : Bearer token (utilisateur connecte)
**Cache** : 30 secondes cote serveur (pas besoin de rafraichir plus souvent)

### Response (200 OK)

```json
{
  "active_users": 47,
  "blocked_apps_users": 31,
  "total_minutes_today": 2341,
  "heatmap": [
    {
      "city": "Paris",
      "lat": 48.8566,
      "lon": 2.3522,
      "intensity": 15
    },
    {
      "city": "Tokyo",
      "lat": 35.6762,
      "lon": 139.6503,
      "intensity": 12
    }
  ],
  "country_leaderboard": [
    {
      "country": "Japan",
      "country_code": "JP",
      "total_minutes": 18500,
      "active_users": 42
    },
    {
      "country": "France",
      "country_code": "FR",
      "total_minutes": 15200,
      "active_users": 38
    }
  ]
}
```

---

## Champs expliques

| Champ | Type | Description |
|-------|------|-------------|
| `active_users` | int | Nombre d'utilisateurs avec une session `status = 'active'` en ce moment |
| `blocked_apps_users` | int | Nombre d'utilisateurs actifs qui ont `apps_blocked = true` sur leur session |
| `total_minutes_today` | int | Somme des `duration_minutes` de toutes les sessions completees aujourd'hui (UTC day) |
| `heatmap` | array | Liste de villes avec activite de focus (agrege, anonyme) |
| `heatmap[].city` | string | Nom de la ville |
| `heatmap[].lat` | float | Latitude de la ville |
| `heatmap[].lon` | float | Longitude de la ville |
| `heatmap[].intensity` | int | Nombre de sessions actives + completees aujourd'hui dans cette ville |
| `country_leaderboard` | array | Classement des pays par minutes de focus aujourd'hui, trie par `total_minutes` DESC |
| `country_leaderboard[].country` | string | Nom du pays en anglais |
| `country_leaderboard[].country_code` | string | Code ISO 3166-1 alpha-2 (ex: "FR", "US", "JP") |
| `country_leaderboard[].total_minutes` | int | Total des minutes de focus aujourd'hui pour ce pays |
| `country_leaderboard[].active_users` | int | Nombre d'utilisateurs de ce pays avec une session active en ce moment |

---

## Modifications DB requises

### Option A : Ajouter des colonnes a `focus_sessions`

```sql
ALTER TABLE focus_sessions
  ADD COLUMN city TEXT,
  ADD COLUMN country TEXT,
  ADD COLUMN country_code VARCHAR(2),
  ADD COLUMN latitude DOUBLE PRECISION,
  ADD COLUMN longitude DOUBLE PRECISION,
  ADD COLUMN apps_blocked BOOLEAN DEFAULT false;
```

Ces champs sont remplis au **demarrage** de la session (quand le client POST /focus-sessions).

### Option B : Utiliser la table `users` (si location deja stockee)

Si les users ont deja `city`, `country`, `latitude`, `longitude` dans la table `users` (via `POST /me/location`), tu peux JOIN dessus au lieu de dupliquer. C'est plus simple mais moins precis (la ville de la session vs la derniere ville connue de l'user).

**Recommandation** : Option B pour commencer (plus rapide, pas de migration lourde), puis Option A plus tard si on veut la precision par session.

---

## Modifier : `POST /focus-sessions`

Accepter des champs optionnels supplementaires au demarrage de session :

```json
{
  "duration_minutes": 25,
  "quest_id": "uuid-or-null",
  "description": "Working on Focus Map",
  "latitude": 48.8566,
  "longitude": 2.3522,
  "city": "Paris",
  "country": "France",
  "country_code": "FR",
  "apps_blocked": true
}
```

Tous les nouveaux champs sont **optionnels** — les anciens clients qui n'envoient pas ces champs continuent de fonctionner normalement.

---

## Queries SQL de reference

### active_users
```sql
SELECT COUNT(DISTINCT user_id)
FROM focus_sessions
WHERE status = 'active';
```

### blocked_apps_users
```sql
SELECT COUNT(DISTINCT user_id)
FROM focus_sessions
WHERE status = 'active' AND apps_blocked = true;
```

### total_minutes_today
```sql
SELECT COALESCE(SUM(duration_minutes), 0)
FROM focus_sessions
WHERE status = 'completed'
  AND completed_at >= CURRENT_DATE;
```

### heatmap (avec join sur users pour Option B)
```sql
SELECT
  u.city,
  u.latitude AS lat,
  u.longitude AS lon,
  COUNT(*) AS intensity
FROM focus_sessions fs
JOIN users u ON u.id = fs.user_id
WHERE fs.status IN ('active', 'completed')
  AND fs.started_at >= CURRENT_DATE
  AND u.city IS NOT NULL
GROUP BY u.city, u.latitude, u.longitude
ORDER BY intensity DESC
LIMIT 50;
```

### country_leaderboard
```sql
SELECT
  u.country,
  u.country_code,
  COALESCE(SUM(CASE WHEN fs.status = 'completed' AND fs.completed_at >= CURRENT_DATE
    THEN fs.duration_minutes ELSE 0 END), 0) AS total_minutes,
  COUNT(DISTINCT CASE WHEN fs.status = 'active' THEN fs.user_id END) AS active_users
FROM focus_sessions fs
JOIN users u ON u.id = fs.user_id
WHERE fs.started_at >= CURRENT_DATE
  AND u.country IS NOT NULL
GROUP BY u.country, u.country_code
ORDER BY total_minutes DESC
LIMIT 30;
```

---

## Implementation Go

### Handler

```go
// GET /focus-sessions/live-stats
func (h *FocusSessionHandler) GetLiveStats(w http.ResponseWriter, r *http.Request) {
    stats, err := h.service.GetLiveStats(r.Context())
    if err != nil {
        respondError(w, http.StatusInternalServerError, err.Error())
        return
    }
    respondJSON(w, http.StatusOK, stats)
}
```

### Route (Chi)

```go
r.Get("/focus-sessions/live-stats", h.GetLiveStats)
```

> **Important** : placer cette route AVANT `/focus-sessions/{id}` dans le router sinon "live-stats" sera matche comme un ID.

### Response struct

```go
type LiveStatsResponse struct {
    ActiveUsers       int                    `json:"active_users"`
    BlockedAppsUsers  int                    `json:"blocked_apps_users"`
    TotalMinutesToday int                    `json:"total_minutes_today"`
    Heatmap           []HeatmapPoint         `json:"heatmap"`
    CountryLeaderboard []CountryLeaderEntry  `json:"country_leaderboard"`
}

type HeatmapPoint struct {
    City      string  `json:"city"`
    Lat       float64 `json:"lat"`
    Lon       float64 `json:"lon"`
    Intensity int     `json:"intensity"`
}

type CountryLeaderEntry struct {
    Country     string `json:"country"`
    CountryCode string `json:"country_code"`
    TotalMinutes int   `json:"total_minutes"`
    ActiveUsers  int   `json:"active_users"`
}
```

### Cache

Mettre un cache en memoire de 30 secondes sur ce endpoint (ca sera appele toutes les 30s par chaque client qui a la map ouverte) :

```go
var (
    liveStatsCache     *LiveStatsResponse
    liveStatsCacheTime time.Time
    liveStatsMu        sync.RWMutex
)

func (s *FocusSessionService) GetLiveStats(ctx context.Context) (*LiveStatsResponse, error) {
    liveStatsMu.RLock()
    if liveStatsCache != nil && time.Since(liveStatsCacheTime) < 30*time.Second {
        defer liveStatsMu.RUnlock()
        return liveStatsCache, nil
    }
    liveStatsMu.RUnlock()

    // Fetch fresh data...
    stats := &LiveStatsResponse{}
    // ... queries ...

    liveStatsMu.Lock()
    liveStatsCache = stats
    liveStatsCacheTime = time.Now()
    liveStatsMu.Unlock()

    return stats, nil
}
```

---

## Checklist

- [ ] Creer le handler `GetLiveStats`
- [ ] Ajouter la route `GET /focus-sessions/live-stats` (avant les routes avec `{id}`)
- [ ] Queries pour `active_users`, `blocked_apps_users`, `total_minutes_today`
- [ ] Query heatmap (join users pour la ville)
- [ ] Query country_leaderboard (group by country, order by total_minutes DESC)
- [ ] Cache 30s en memoire
- [ ] Modifier `POST /focus-sessions` pour accepter `latitude`, `longitude`, `city`, `country`, `country_code`, `apps_blocked` (optionnels)
- [ ] Migration DB si Option A (ajouter colonnes a `focus_sessions`)
- [ ] Tester avec `curl` ou Postman
