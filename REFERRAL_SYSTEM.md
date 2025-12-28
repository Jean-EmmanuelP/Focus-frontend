# Systeme de Parrainage (Referral) - Documentation Complete

## Resume de ce qui a ete fait

### Backend (Go) - `/Focus_backend/firelevel-backend/`

| Fichier | Description |
|---------|-------------|
| `internal/referral/handler.go` | Handlers HTTP pour tous les endpoints |
| `internal/referral/repository.go` | Operations base de donnees |
| `internal/referral/migrations.sql` | Schema SQL des tables |
| `cmd/api/main.go` | Routes ajoutees |

**Endpoints crees :**
- `GET /referral/stats` - Stats et code du user
- `GET /referral/list` - Liste des filleuls
- `GET /referral/earnings` - Historique des commissions
- `POST /referral/apply` - Appliquer un code
- `POST /referral/activate` - Activer apres abonnement
- `GET /referral/validate?code=XXX` - Valider un code (public)

### iOS (Swift) - `/Focus/`

| Fichier | Description |
|---------|-------------|
| `Focus/Services/ReferralService.swift` | Service API + gestion d'etat |
| `Focus/Views/Settings/ReferralView.swift` | Vue parrainage dans Settings |
| `Focus/Views/Settings/SettingsView.swift` | Bandeau parrainage ajoute |
| `Focus/Views/Onboarding/OnboardingView.swift` | Champ code + message Paywall |
| `Focus/Core/APIClient.swift` | Endpoints ajoutes |
| `Focus/Core/AppStore.swift` | Application auto du code apres login |
| `Focus/App/FocusApp.swift` | Deep link handling |

---

## Migration SQL a executer

### Etape 1 : Ouvrir Supabase

1. Va sur https://supabase.com/dashboard
2. Selectionne ton projet Focus
3. Clique sur "SQL Editor" dans le menu gauche
4. Clique sur "New query"

### Etape 2 : Copier et executer ce SQL

```sql
-- ============================================
-- REFERRAL SYSTEM TABLES
-- ============================================

-- 1. Referral Codes (unique code per user)
CREATE TABLE IF NOT EXISTS referral_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_code UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_user ON referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);

-- 2. Referrals (relationship between referrer and referred)
CREATE TABLE IF NOT EXISTS referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    referred_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    referral_code_id UUID NOT NULL REFERENCES referral_codes(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'churned')),
    referred_at TIMESTAMPTZ DEFAULT NOW(),
    activated_at TIMESTAMPTZ,
    churned_at TIMESTAMPTZ,
    CONSTRAINT unique_referred UNIQUE (referred_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON referrals(status);

-- 3. Referral Earnings (monthly commission tracking)
CREATE TABLE IF NOT EXISTS referral_earnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    referral_id UUID NOT NULL REFERENCES referrals(id) ON DELETE CASCADE,
    month DATE NOT NULL,
    subscription_amount DECIMAL(10,2) NOT NULL,
    commission_rate DECIMAL(5,4) NOT NULL DEFAULT 0.20,
    commission_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'credited', 'paid')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    credited_at TIMESTAMPTZ,
    CONSTRAINT unique_earning_per_month UNIQUE (referral_id, month)
);

CREATE INDEX IF NOT EXISTS idx_referral_earnings_referrer ON referral_earnings(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referral_earnings_status ON referral_earnings(status);
CREATE INDEX IF NOT EXISTS idx_referral_earnings_month ON referral_earnings(month);

-- 4. Referral Credits (user balance for earned commissions)
CREATE TABLE IF NOT EXISTS referral_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    total_earned DECIMAL(10,2) NOT NULL DEFAULT 0,
    current_balance DECIMAL(10,2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referral_credits_user ON referral_credits(user_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_credits ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view own referral code" ON referral_codes;
DROP POLICY IF EXISTS "Anyone can validate codes" ON referral_codes;
DROP POLICY IF EXISTS "Service role full access referral_codes" ON referral_codes;
DROP POLICY IF EXISTS "Referrers can view their referrals" ON referrals;
DROP POLICY IF EXISTS "Users can see if they were referred" ON referrals;
DROP POLICY IF EXISTS "Service role full access referrals" ON referrals;
DROP POLICY IF EXISTS "Users can view own earnings" ON referral_earnings;
DROP POLICY IF EXISTS "Service role full access referral_earnings" ON referral_earnings;
DROP POLICY IF EXISTS "Users can view own credits" ON referral_credits;
DROP POLICY IF EXISTS "Service role full access referral_credits" ON referral_credits;

-- Referral Codes policies
CREATE POLICY "Anyone can validate codes"
    ON referral_codes FOR SELECT
    USING (true);

CREATE POLICY "Service role full access referral_codes"
    ON referral_codes FOR ALL
    USING (true);

-- Referrals policies
CREATE POLICY "Referrers can view their referrals"
    ON referrals FOR SELECT
    USING (auth.uid() = referrer_id);

CREATE POLICY "Users can see if they were referred"
    ON referrals FOR SELECT
    USING (auth.uid() = referred_id);

CREATE POLICY "Service role full access referrals"
    ON referrals FOR ALL
    USING (true);

-- Earnings policies
CREATE POLICY "Users can view own earnings"
    ON referral_earnings FOR SELECT
    USING (auth.uid() = referrer_id);

CREATE POLICY "Service role full access referral_earnings"
    ON referral_earnings FOR ALL
    USING (true);

-- Credits policies
CREATE POLICY "Users can view own credits"
    ON referral_credits FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role full access referral_credits"
    ON referral_credits FOR ALL
    USING (true);
```

### Etape 3 : Cliquer sur "Run" (ou Cmd+Enter)

Tu devrais voir "Success. No rows returned" - c'est normal pour des CREATE TABLE.

---

## Ce qu'il reste a faire

### 1. Executer la migration SQL (obligatoire)
- [ ] Copier le SQL ci-dessus dans Supabase SQL Editor
- [ ] Executer et verifier qu'il n'y a pas d'erreur

### 2. Deployer le backend (obligatoire)
- [ ] Push sur Railway/Render pour deployer les nouveaux endpoints
- [ ] Verifier que le build passe

### 3. Configurer RevenueCat Webhook (recommande)
Quand un user s'abonne, il faut activer le referral automatiquement.

**Option A : Webhook RevenueCat**
1. Dans RevenueCat Dashboard > Project > Integrations > Webhooks
2. Ajouter URL : `https://ton-backend.com/webhooks/revenuecat`
3. Creer le handler dans le backend (a faire)

**Option B : Appel manuel depuis iOS**
Deja fait ! Apres l'achat reussi, on appelle `ReferralService.shared.activateReferral()`

### 4. Cron job mensuel pour les commissions (optionnel pour l'instant)
Chaque mois, appeler `POST /jobs/referral/process-commissions` pour :
- Calculer les commissions des referrals actifs
- Crediter les balances des parrains

**Options :**
- Railway Cron
- Vercel Cron
- GitHub Actions (schedule)
- Supabase Edge Functions + pg_cron

### 5. Universal Links (optionnel)
Pour que `https://focus.app/r/CODE` fonctionne :

1. **Apple Developer Portal :**
   - Associated Domains capability
   - Ajouter `applinks:focus.app`

2. **Heberger sur focus.app :**
   ```json
   // /.well-known/apple-app-site-association
   {
     "applinks": {
       "apps": [],
       "details": [{
         "appID": "TEAMID.com.focus.app",
         "paths": ["/r/*"]
       }]
     }
   }
   ```

Pour l'instant, le deep link `focus://referral?code=XXX` fonctionne deja.

---

## Comment ca marche (flux complet)

### Scenario : Marie parraine Paul

```
1. Marie ouvre Settings > Parrainage
   → Son code unique est genere : "MARI-A5F2D"
   → Elle partage le lien

2. Paul clique sur le lien
   → Deep link : focus://referral?code=MARI-A5F2D
   → Code stocke dans UserDefaults

3. Paul fait l'onboarding
   → FeaturesRecap : pas de champ code (deja stocke)
   → Paywall : message "Invite par un ami - Merci a ton parrain !"

4. Paul paie l'abonnement
   → POST /referral/apply (lie Paul a Marie)
   → POST /referral/activate (status = active)

5. Chaque mois (cron job)
   → Calcul commission : 9.99€ x 20% = 2€
   → Credit sur le compte de Marie

6. Marie voit dans Settings > Parrainage
   → 1 filleul actif
   → 2€ de solde
```

---

## Structure des tables

### referral_codes
| Colonne | Type | Description |
|---------|------|-------------|
| id | UUID | PK |
| user_id | UUID | FK users |
| code | VARCHAR(20) | Ex: "MARI-A5F2D" |
| created_at | TIMESTAMP | Date creation |

### referrals
| Colonne | Type | Description |
|---------|------|-------------|
| id | UUID | PK |
| referrer_id | UUID | Le parrain |
| referred_id | UUID | Le filleul |
| status | VARCHAR | pending/active/churned |
| referred_at | TIMESTAMP | Date inscription |
| activated_at | TIMESTAMP | Date 1er paiement |

### referral_earnings
| Colonne | Type | Description |
|---------|------|-------------|
| id | UUID | PK |
| referrer_id | UUID | Le parrain |
| referral_id | UUID | FK referrals |
| month | DATE | Mois (YYYY-MM-01) |
| subscription_amount | DECIMAL | Prix abo |
| commission_amount | DECIMAL | 20% du prix |
| status | VARCHAR | pending/credited |

### referral_credits
| Colonne | Type | Description |
|---------|------|-------------|
| id | UUID | PK |
| user_id | UUID | FK users |
| total_earned | DECIMAL | Total gagne |
| current_balance | DECIMAL | Solde actuel |

---

## Commits effectues

1. `9fc7471` - Backend : package referral complet
2. `edf8fbf` - iOS : ReferralService + ReferralView + Settings
3. `9719edf` - iOS : champ code dans FeaturesRecap
4. `651935f` - iOS : amelioration UX deep link + message Paywall
