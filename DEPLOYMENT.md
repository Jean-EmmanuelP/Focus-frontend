# Focus - Guide de Déploiement

## Prérequis

- Xcode installé
- Fastlane installé (`brew install fastlane`)
- Compte Apple Developer configuré
- Certificats et provisioning profiles valides dans Xcode

---

## Commandes Rapides

| Action | Commande |
|--------|----------|
| Build debug | `fastlane build` |
| Voir version | `fastlane version` |
| Push TestFlight | `fastlane beta` |
| Push App Store | `fastlane release` |

---

## 1. Déployer sur TestFlight (Beta)

### Commande unique
```bash
cd /Users/jperrama/Developer/iOS_Swift_Applications/Focus
fastlane beta
```

### Ce que ça fait automatiquement
1. Incrémente le build number (1 → 2 → 3...)
2. Compile l'app en Release
3. Signe avec les certificats App Store
4. Upload sur App Store Connect
5. Commit le changement de version

### Première utilisation
Fastlane demandera:
- **Apple ID**: ton email Apple Developer
- **App-specific password**: générer sur https://appleid.apple.com/account/manage → App-Specific Passwords

### Après upload
- L'app apparaît dans App Store Connect sous "TestFlight"
- Processing prend ~10-30 minutes
- Les testeurs internes reçoivent automatiquement
- Pour testeurs externes: activer manuellement dans App Store Connect

---

## 2. Déployer sur l'App Store (Production)

### Commande unique
```bash
cd /Users/jperrama/Developer/iOS_Swift_Applications/Focus
fastlane release
```

### Ce que ça fait automatiquement
1. Vérifie que git est clean
2. Incrémente la version (1.7 → 1.7.1)
3. Incrémente le build number
4. Compile en Release
5. Upload sur App Store Connect
6. Commit + tag git (v1.7.1)

### Après upload
1. Aller sur https://appstoreconnect.apple.com
2. Sélectionner Focus
3. Aller dans "App Store" → Version
4. Remplir les notes de version (What's New)
5. Cliquer "Submit for Review"

---

## 3. Versioning

### Voir la version actuelle
```bash
fastlane version
# Output: Current version: 1.7 (1)
```

### Incrémenter manuellement

```bash
# Build number seulement (pour TestFlight)
fastlane bump          # 1 → 2

# Version patch (bug fixes)
fastlane bump_patch    # 1.7.0 → 1.7.1

# Version minor (nouvelles features)
fastlane bump_minor    # 1.7 → 1.8

# Version major (breaking changes)
fastlane bump_major    # 1.7 → 2.0
```

---

## 4. Troubleshooting

### "No signing certificate"
```bash
# Ouvrir Xcode et vérifier Signing & Capabilities
# Ou régénérer les certificats:
fastlane certs_prod
```

### "App-specific password required"
1. Aller sur https://appleid.apple.com/account/manage
2. Security → App-Specific Passwords
3. Générer un nouveau password
4. L'utiliser quand Fastlane le demande

### "Build failed"
```bash
# Nettoyer et réessayer
fastlane clean
fastlane beta
```

### Session expirée
```bash
# Fastlane redemandera le login automatiquement
# Ou forcer:
fastlane spaceauth -u ton.email@icloud.com
```

---

## 5. Workflow Recommandé

### Pour une beta rapide (bug fix)
```bash
git add . && git commit -m "fix: description"
fastlane beta
```

### Pour une release App Store
```bash
# 1. S'assurer que tout est mergé sur main
git checkout main
git pull

# 2. Vérifier que ça compile
fastlane build

# 3. Release
fastlane release

# 4. Push les tags
git push && git push --tags
```

---

## 6. Structure Fastlane

```
Focus/
├── fastlane/
│   ├── Appfile      # Config (bundle ID, team ID)
│   ├── Fastfile     # Lanes (commandes)
│   └── Pluginfile   # Plugins optionnels
├── Gemfile          # Dépendances Ruby
└── DEPLOYMENT.md    # Ce fichier
```

---

## 7. Contacts & Resources

- **App Store Connect**: https://appstoreconnect.apple.com
- **Apple Developer**: https://developer.apple.com
- **Fastlane Docs**: https://docs.fastlane.tools
- **Bundle ID**: `com.jep.volta`
- **Team ID**: `62NW6K29QN`
