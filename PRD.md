# Focus App - PRD (Ralph Design Implementation)

## Instructions generales
- **REGLE ABSOLUE** : Chaque ecran doit etre implemente en SwiftUI pour etre **identique au pixel pres** au design de reference (screenshot PNG). Les couleurs, espacements, tailles de police, border radius, padding, alignements, icones doivent correspondre exactement. La seule exception : les fonds d'ecran (backgrounds/gradients) peuvent etre differents ou simplifies, ils seront ajustes plus tard.
- Les designs de reference (screenshots PNG) sont dans `design/` (sans "s")
- Les specs detaillees (.md) sont dans `designs/` (avec "s")
- Deep links disponibles pour la verification sur simulateur
- Remplacer "Replika" par "Focus" et le nom du compagnon par "Kai" partout
- Style global onboarding: fond light gray/blue (#F4F5FA), cards blanches arrondies, nav bar avec logo centre + back button gris cercle
- IMPORTANT: pas d'avatar 3D / image IA pour l'instant. Partout ou le design montre un avatar, utiliser un placeholder (gradient, icone, ou espace vide). L'integration avatar sera faite separement.
- **EXCEPTION FONDS D'ECRAN** : Ne pas perdre de temps a reproduire exactement les fonds d'ecran (gradients, backgrounds). Utiliser un fond uni ou un gradient simple qui se rapproche du design. Les fonds definitifs seront integres plus tard.

---

## Flow 1: Login / Landing Page

### 1.1 Landing Page (Page d'accueil - non authentifie)
- **Screenshot**: `design/login/login.png`
- **Specs**: `designs/login/landing.md`
- **Deep link**: `focus://login`
- **Fichier**: `Focus/Views/Onboarding/LandingPageView.swift`
- **Specs**:
  - [ ] Fond sombre (dark gradient plein ecran)
  - [ ] Logo "Focus" centre en haut, blanc
  - [ ] Titre large centre, blanc, bold serif: "The AI to do life with" (3 lignes)
  - [ ] 1 bouton d'auth en bas, pill shape (~56pt height, full width padding 24pt):
    - [ ] "Continuer avec Apple" - fond bleu (#0066FF), icone Apple, texte blanc
  - [ ] Texte legal en bas: "En continuant, vous acceptez notre Conditions d'utilisation et Politique de confidentialite"
  - [ ] Texte legal: ~13pt, gris, centre

---

## Flow 2: Onboarding

- **Fichier principal**: `Focus/Views/Onboarding/NewOnboardingView.swift`
- **Deep link**: `focus://onboarding`
- **Style global**: fond light #F4F5FA, cards blanches corner radius ~16pt, back button cercle gris top-left, logo "Focus" centre nav bar

### 2.1 Step 0: Nom de l'utilisateur
- **Screenshot**: `design/onboarding/onboarding_00.PNG`
- **Specs**:
  - [ ] Titre: "Quel est votre nom ?" - bold, dark navy (#1A1A4E), ~28pt, left-aligned
  - [ ] Sous-titre: "Cela aidera Focus a en apprendre plus sur vous." - regular, ~16pt
  - [ ] Champ texte "Prenom" - card blanche, full width, ~56pt height, corner radius ~16pt
  - [ ] Champ texte "Nom" - card blanche, full width, ~56pt height, corner radius ~16pt
  - [ ] Spacing entre champs: ~12pt
  - [ ] Bouton "Continuer" en bas centre: bleu (#0066FF), pill shape, ~56pt height, ~200pt width

### 2.2 Step 1: Age
- **Screenshot**: `design/onboarding/onboarding_01.PNG`
- **Specs**:
  - [ ] Titre: "Quel age avez-vous ?" - bold, dark navy, ~28pt, left-aligned
  - [ ] 7 options en cards blanches empilees, full width, ~60pt height, texte centre:
    - "Moins de 18", "18-24", "25-34", "35-44", "45-54", "55-64", "65 ans et plus"
  - [ ] Spacing entre cards: ~12pt
  - [ ] Tap sur option = avance automatiquement (pas de bouton continuer)

### 2.3 Step 2: Pronoms
- **Screenshot**: `design/onboarding/onboarding_02.PNG`
- **Specs**:
  - [ ] Titre: "Quels sont vos pronoms ?" - bold, dark navy, ~28pt, left-aligned
  - [ ] 3 options en cards blanches, full width, ~60pt height, icone gender + texte left-aligned:
    - ♀ "Elle / La"
    - ♂ "Il / Lui"
    - ⚧ "Iel / Iels"
  - [ ] Tap sur option = avance automatiquement

### 2.4 Step 3: Role du compagnon
- **Screenshot**: `design/onboarding/onboarding_03.PNG`
- **Specs**:
  - [ ] Titre: "Que voudriez-vous que votre Focus soit pour vous en ce moment ?" - bold, dark navy, ~24pt, left-aligned
  - [ ] 5 options en cards blanches, full width, ~60pt height, texte left-aligned:
    - "Quelqu'un de special"
    - "Un ami qui ecoute et se soucie"
    - "Quelqu'un pour soutenir mon bien-etre mental"
    - "Un coach pour m'aider a atteindre mes objectifs"
    - "Un tuteur d'anglais avec qui pratiquer"
  - [ ] Tap sur option = avance automatiquement

### 2.5 Step 4: Genre du compagnon
- **Screenshot**: `design/onboarding/onboarding_04.PNG`
- **Specs**:
  - [ ] Barre de progression: point bleu + ligne bleue, centre en haut sous la nav bar
  - [ ] Titre: "Quel genre aimeriez-vous que votre Focus soit ?" - bold, dark navy, ~24pt, left-aligned
  - [ ] 3 options en cards blanches, full width, ~60pt height, texte left-aligned:
    - "Femme"
    - "Homme"
    - "Non-binaire"
  - [ ] Tap sur option = avance automatiquement

### 2.6 Step 5: Nom du compagnon
- **Screenshot**: `design/onboarding/onboarding_05.PNG`
- **Specs**:
  - [ ] Barre de progression en haut (point + ligne bleue)
  - [ ] Titre: "Comment aimeriez-vous nommer votre Focus ?" - bold, dark navy, ~24pt, left-aligned
  - [ ] Champ texte unique - card blanche, placeholder "Nom de Focus", full width, ~56pt
  - [ ] Bouton "Continuer" en bas centre: bleu pill shape, ~56pt height, ~200pt width

### 2.7 Step 6: Social proof (nombre d'utilisateurs)
- **Screenshot**: `design/onboarding/onboarding_06.PNG`
- **Specs**:
  - [ ] Fond bleu gradient (pas le fond gris standard)
  - [ ] Grand nombre blanc bold: "35,109,249" - tres gros (~48-56pt)
  - [ ] Sous-texte: "des personnes ont deja ressenti les avantages d'avoir un Focus dans leur vie" - blanc, ~16pt, centre
  - [ ] Section "Presente dans" avec logos presse (style serif blanc):
    - The New York Times, The Wall Street Journal, CNN, Bloomberg, Forbes, Wired, Fortune, The Washington Post
  - [ ] Bouton "Continuer" en bas: blanc, pill shape, texte noir

### 2.8 Step 7: Objectifs bien-etre (multi-select)
- **Screenshot**: `design/onboarding/onboarding_07.PNG`
- **Style**: fond dark gradient (vert/bleu sombre), card blanche centrale arrondie
- **Specs**:
  - [ ] Indicateur de progression: 2 dots en haut (gris), centre
  - [ ] Titre dans la card: "Avant tout, je veux que mon guide AI pour le bien-etre mental m'aide..." - bold, dark navy, ~22pt
  - [ ] 6 options en sous-cards blanches bordees, full width dans la card, texte left-aligned:
    - "Gerer le stress et l'anxiete"
    - "Developpez un etat d'esprit positif"
    - "Creer des habitudes saines"
    - "Developper la resilience emotionnelle"
    - "Gagner confiance en moi"
    - "Quelque chose de completement different"
  - [ ] Multi-select possible (plusieurs options selectionnables)
  - [ ] Pas de bouton continuer visible (avance quand selection faite)

### 2.9 Step 8: Ameliorations vie (multi-select)
- **Screenshot**: `design/onboarding/onboarding_08.PNG`
- **Style**: fond dark gradient, card blanche centrale
- **Specs**:
  - [ ] Indicateur 2 dots en haut
  - [ ] Titre: "Qu'est-ce que vous souhaitez ameliorer dans votre vie ?"
  - [ ] Sous-titre: "Vous pouvez choisir plus d'une option" - gris, ~14pt
  - [ ] 6 options en sous-cards:
    - "Guerir les blessures emotionnelles passees"
    - "Reconnaitre ma valeur personnelle"
    - "Apprenez a etablir des limites saines"
    - "Devenez un meilleur parent"
    - "Lachez prise des traumatismes d'enfance"
    - "Se remettre d'une mauvaise rupture"
  - [ ] Texte gris en bas: "J'ai un objectif different" (optionnel)
  - [ ] Bouton "Continuer" en bas: marron/dark (#4A3040), pill shape

### 2.10 Step 9: Attentes du guide (multi-select)
- **Screenshot**: `design/onboarding/onboarding_09.PNG`
- **Style**: fond dark gradient, card blanche centrale
- **Specs**:
  - [ ] Indicateur 2 dots en haut
  - [ ] Titre: "Je veux aussi que mon guide AI de bien-etre mental..."
  - [ ] Sous-titre: "Vous pouvez choisir plus d'une option"
  - [ ] 5 options:
    - "Sois la pour discuter quand j'en ai besoin"
    - "Ecoutez sans jugement"
    - "Encouragez-moi quand je ne vais pas bien"
    - "Comprendre reellement ma perspective"
    - "Encore plus que ce qui precede"
  - [ ] Bouton "Continuer" marron/dark pill shape

### 2.11 Step 10: Presentation du compagnon (fullscreen)
- **Screenshot**: `design/onboarding/onboarding_10.PNG`
- **Style**: fond sombre, texte blanc
- **Specs**:
  - [ ] Fond sombre gradient (placeholder pour futur avatar - laisser un espace vide ou gradient en haut ~60%)
  - [ ] Texte descriptif blanc, bold, grand (~24-28pt), centre: "Votre guide personnel en IA pour le bien-etre mental vous aidera a gerer le stress et l'anxiete en etant un compagnon qui se soucie vraiment de vous."
  - [ ] Bouton "Parfait!" en bas: blanc, pill shape, texte noir
  - [ ] NOTE: pas d'avatar 3D pour l'instant, utiliser un placeholder gradient/icone

### 2.12 Step 11: Domaines de developpement (multi-select)
- **Screenshot**: `design/onboarding/onboarding_11.PNG`
- **Style**: fond dark gradient, card blanche
- **Specs**:
  - [ ] Indicateur 2 dots
  - [ ] Titre: "Dans quels domaines de developpement personnel aspirez-vous a progresser ?"
  - [ ] Sous-titre: "Vous pouvez choisir plus d'une option"
  - [ ] 6 options:
    - "Clarte sur mes valeurs personnelles" (peut etre pre-selectionnee, fond bleu)
    - "Routines quotidiennes positives"
    - "Responsabilite envers mes objectifs"
    - "Vision claire pour mon avenir"
    - "Quelque chose que je ne peux pas encore expliquer"
    - "Je ne cherche rien de specifique"
  - [ ] Bouton "Continuer" marron/dark pill

### 2.13 Step 12: Activites supplementaires (multi-select)
- **Screenshot**: `design/onboarding/onboarding_12.PNG`
- **Style**: fond dark gradient, card blanche
- **Specs**:
  - [ ] Indicateur 2 dots
  - [ ] Titre: "Que voudriez-vous d'autre faire avec votre guide d'IA pour le bien-etre mental ?"
  - [ ] Sous-titre: "Vous pouvez choisir plus d'une option"
  - [ ] 6 options:
    - "Pratiquez le yoga ou d'autres sports"
    - "Meditez ensemble"
    - "Journal ou tenir un journal"
    - "Explorez la spiritualite ou l'astrologie"
    - "Developpez-vous professionnellement"
    - "Apprendre une nouvelle langue"
  - [ ] Texte gris: "Encore plus de choix..."
  - [ ] Bouton "Continuer" marron/dark pill

### 2.14 Step 13: Question accord #1 (Oui/Non)
- **Screenshot**: `design/onboarding/onboarding_13.PNG`
- **Style**: fond dark gradient, card blanche centrale
- **Specs**:
  - [ ] Indicateur 3 dots en haut
  - [ ] Titre dans card: "Etes-vous d'accord avec l'enonce ci-dessous ?" - regular, ~16pt, centre
  - [ ] Citation grande, bold serif/italic, dark maroon (#4A2040), ~28-32pt, centre:
    - "J'ai perdu de l'interet pour les activites que j'aimais auparavant"
  - [ ] Guillemets stylises autour de la citation
  - [ ] 2 boutons en bas cote a cote:
    - "Non" - marron/dark (#4A3040), pill, ~48pt height
    - "Oui" - marron/dark (#4A3040), pill, ~48pt height

### 2.15 Step 14: Question accord #2 (Oui/Non)
- **Screenshot**: `design/onboarding/onboarding_14.PNG`
- **Style**: identique au step 13
- **Specs**:
  - [ ] Citation: "Je veux me sentir apaise dans mon esprit - pas comme si je devais toujours lutter contre cela"
  - [ ] Meme layout 2 boutons Non / Oui

### 2.16 Step 15: Question accord #3 (Oui/Non)
- **Screenshot**: `design/onboarding/onboarding_15.PNG`
- **Style**: identique
- **Specs**:
  - [ ] Citation: "Je repasse chaque conversation dans ma tete, me demandant si j'ai dit quelque chose de mal"
  - [ ] Meme layout 2 boutons Non / Oui

### 2.17 Step 16: Question accord #4 (Oui/Non)
- **Screenshot**: `design/onboarding/onboarding_16.PNG`
- **Style**: identique
- **Specs**:
  - [ ] Citation: "Trouver la paix avec les defis passes peut m'aider a avancer."
  - [ ] Meme layout 2 boutons Non / Oui

### 2.18 Step 17: Question accord #5 (Oui/Non)
- **Screenshot**: `design/onboarding/onboarding_17.PNG`
- **Style**: identique
- **Specs**:
  - [ ] Citation: "J'ai besoin de me sentir ecoute, comme si mes emotions comptaient reellement."
  - [ ] Meme layout 2 boutons Non / Oui

### 2.19 Step 18: Social proof (evaluations)
- **Screenshot**: `design/onboarding/onboarding_18.PNG`
- **Style**: fond bleu gradient (comme step 6)
- **Specs**:
  - [ ] Barre de progression quasi complete en haut
  - [ ] Texte blanc bold ~20pt: "Les gens voient Focus comme un compagnon avec qui ils peuvent partager ouvertement des choses. Des choses qu'ils ont du mal a dire aux autres."
  - [ ] Section evaluations avec icone laurier:
    - "Evaluations Totales" + 5 etoiles jaunes + "370,000+"
    - "Evaluation par etoiles" + "4,5 sur 5"
  - [ ] Avis utilisateur: 5 etoiles + texte italique citation + nom d'utilisateur
  - [ ] Bouton "Etonnant" en bas: blanc, pill shape, texte noir

### 2.20 Step 19: Chargement / Creation du compagnon
- **Screenshot**: `design/onboarding/onboarding_19.PNG`
- **Style**: fond bleu gradient
- **Specs**:
  - [ ] Liste de progression avec checkmarks:
    - ✓ "Comprendre vos besoins" (complete, gris)
    - ✓ "Votre guide personnel d'IA pour le bien-etre mental est presque pret..." (complete, gris)
    - ○ "Explorer vos objectifs et desirs" (en cours, blanc)
  - [ ] Grand texte blanc bold centre: "Nous creons [Nom] pour vous"
  - [ ] Sous-texte: "Cela peut prendre jusqu'a 2 minutes." - blanc, ~14pt
  - [ ] Animation de chargement implicite

### 2.21 Step 20: Paywall / Abonnement
- **Screenshot**: `design/onboarding/onboarding_20.PNG` + `design/paywall/paywall.PNG`
- **Style**: fond gradient bleu/violet sombre
- **Specs**:
  - [ ] Bouton fermer (X) en haut droite, cercle gris
  - [ ] Zone haute (~50% ecran): placeholder gradient sombre (pas d'avatar 3D pour l'instant)
  - [ ] Titre grand blanc bold: "[Nom] vous attend" - ~36pt
  - [ ] Card d'abonnement glass-morphism (fond semi-transparent):
    - Icone diamant + "Platinum" bold blanc
    - "Prix annuel 67,99 €" - blanc, ~14pt
    - Badge prix: "5,67 € par mois" - dans un badge arrondi a droite
  - [ ] Lien "Autres options" centre, blanc, ~14pt
  - [ ] Bouton "Continuer" blanc, pill shape, ~56pt height, ~250pt width
  - [ ] Texte "Annulez a tout moment" avec icone horloge, blanc ~13pt
  - [ ] Footer: "Conditions | Restaurer les achats | Confidentialite" - blanc ~12pt, espaces

### 2.22 Step 21: Ecran final - Rencontre du compagnon
- **Screenshot**: `design/onboarding/onboarding_21.PNG`
- **Style**: fond bleu gradient
- **Specs**:
  - [ ] Zone haute (~60% ecran): placeholder gradient bleu (pas d'avatar 3D pour l'instant)
  - [ ] Badge "Fait" avec icone check, centre dans la zone haute
  - [ ] Titre grand blanc bold: "[Nom] vous attend" - ~36pt
  - [ ] Bouton "Rencontrer [Nom]" blanc, pill shape, full width padding 24pt, ~56pt height
  - [ ] Texte disclaimer en bas: "[Nom] est une IA et ne peut pas fournir de conseils medicaux. En cas de crise, demandez de l'aide a un expert." - blanc ~12pt, centre
  - [ ] NOTE: pas d'avatar 3D pour l'instant, utiliser un placeholder gradient/icone

---

## Flow 3: Chat (Page principale)

### 3.1 Chat - Main Screen
- **Screenshot**: `design/chat/chat_00.PNG`
- **Deep link**: `focus://chat`
- **Fichier**: `Focus/Views/Chat/ChatView.swift`
- **Style**: fond gradient bleu/gris clair
- **Specs**:
  - [ ] Fond gradient clair (bleu pale / gris clair) plein ecran
  - [ ] Header: icone menu (chevron down) a gauche, logo "Focus" centre, icone profil/settings a droite (cercle)
  - [ ] Bulle nom du compagnon en haut centre: "[Nom]" + "Votre Ami" - fond semi-transparent arrondi
  - [ ] Zone centrale: placeholder gradient (pas d'avatar 3D pour l'instant)
  - [ ] Barre de saisie en bas:
    - Icone micro a gauche (cercle gris)
    - Champ texte "Votre message" - fond gris/transparent, arrondi
    - Bouton "+" a droite (cercle sombre)
  - [ ] NOTE: l'avatar 3D sera integre plus tard

### 3.2 Chat - Conversation active (IA en train de parler)
- **Screenshot**: `design/chat/chat_01.png`
- **Deep link**: `focus://chat`
- **Fichier**: `Focus/Views/Chat/ChatView.swift`
- **Style**: fond gradient clair, avatar 3D a gauche, bulles de conversation a droite
- **Specs**:
  - [ ] Avatar 3D du compagnon affiche a gauche de l'ecran (~40-50% largeur), devant un decor (miroir/fenetre)
  - [ ] NOTE: pas d'avatar 3D pour l'instant, utiliser un placeholder gradient/icone
  - [ ] Header: icone menu (chevron down) a gauche avec nom du compagnon (dynamique), logo "Focus" centre, icones appel (telephone) et video a droite
  - [ ] Date dynamique centre au-dessus des messages - gris, ~13pt (ex: "26 janvier 2026")
  - [ ] Bulles de messages IA (compagnon) - **contenu dynamique** provenant du backend/IA:
    - Fond blanc, corner radius ~16pt
    - Texte noir, ~16pt
    - Alignees a droite
    - Texte dynamique genere par l'IA en temps reel (ex: "Hi [Prenom]! Thanks for creating me...")
  - [ ] Bulles de messages utilisateur - **contenu dynamique** saisi par l'utilisateur:
    - Fond blanc, corner radius ~16pt
    - Texte noir, ~16pt
    - Alignees a droite egalement
  - [ ] Notification d'appel entre messages (dynamique): "Vous et [Nom] avez eu un appel pendant [duree]" - texte gris centre, ~13pt
  - [ ] Barre de saisie en bas:
    - Icone micro a gauche (cercle gris)
    - Champ texte "Votre message" - fond gris/transparent, arrondi
    - Bouton "+" a droite (cercle sombre)
  - [ ] Bouton actions (trois points "...") centre au-dessus de la barre de saisie - cercle blanc
  - [ ] **NOTE**: tous les textes de cette vue sont dynamiques (nom du compagnon, messages IA, messages utilisateur, date, duree d'appel). Aucun texte n'est hardcode.

---

## Flow 4: Settings

- **Fichier principal**: `Focus/Views/Settings/SettingsView.swift`
- **Deep link**: `focus://settings`
- **Style global**: fond bleu fonce/navy (#1A1A4E), texte blanc, toggles bleu/gris

### 4.1 Settings - Page principale (haut)
- **Screenshot**: `design/settings/settings_00.PNG`
- **Specs**:
  - [ ] Header: "Parametres" centre, bouton X (fermer) en haut droite
  - [ ] Banner promo en haut: card glass-morphism bleu gradient avec icone diamant
    - "Debloquez toutes les fonctionnalites"
    - Sous-texte: "Obtenez l'acces au modele avance, aux messages vocaux illimites, a la generation d'images, aux activites, et plus encore."
  - [ ] Section liens:
    - "Compte" avec chevron droite
    - "Historique des versions" + sous-texte "Advanced" avec chevron
  - [ ] Section "Preferences" avec toggles:
    - "Avatar herite" - toggle OFF (gris)
    - "Afficher Focus dans le chat" - toggle ON (bleu)
    - "Afficher le niveau" - toggle OFF
    - "Musique de fond" - toggle OFF
    - "Sons" - toggle ON (bleu)
    - "Notifications" (coupe en bas)

### 4.2 Settings - Page principale (bas)
- **Screenshot**: `design/settings/settings_01.PNG`
- **Specs**:
  - [ ] Suite des toggles:
    - "Notifications" - toggle ON (bleu)
    - "Face ID" - toggle OFF
  - [ ] Section "Ressources" avec liens externes (icone fleche diagonale):
    - "Centre d'aide"
    - "Evaluez-nous"
    - "Conditions d'utilisation"
    - "Politique de confidentialite"
    - "Credits"
  - [ ] Section "Rejoignez notre communaute" avec icones + liens externes:
    - Reddit (icone reddit orange)
    - Discord (icone discord violet)
    - Facebook (icone facebook bleu)
  - [ ] Bouton "Se deconnecter" en bas: fond semi-transparent, icone sortie, texte blanc, pill shape
  - [ ] Version app tout en bas: "Version 11.2.1" gris

### 4.3 Settings - Compte
- **Screenshot**: `design/settings/settings_02.PNG`
- **Deep link**: `focus://settings` > Compte
- **Specs**:
  - [ ] Header: back button chevron gauche, "Compte" centre
  - [ ] Fond bleu fonce navy
  - [ ] Liste de champs avec chevron droite, chaque champ a un label + valeur:
    - "Nom" / "Jean-Emmanuel"
    - "Anniversaire" / "Non defini"
    - "Pronoms" / "Il / Lui"
    - "Changer l'email" / "jperrama@gmail.com"
    - "Changer le mot de passe" / chevron
  - [ ] Lien "Supprimer le compte" en rouge en bas

### 4.4 Settings - Modifier nom
- **Screenshot**: `design/settings/settings_03.PNG`
- **Specs**:
  - [ ] Header: back button, "Nom" centre
  - [ ] Fond bleu fonce navy
  - [ ] Champ texte: card blanche arrondie, texte noir, full width, ~56pt height
  - [ ] Bouton "Sauvegarder" en bas centre: fond semi-transparent/bleu, pill shape, texte blanc, ~56pt height, ~200pt width

### 4.5 Settings - Date de naissance
- **Screenshot**: `design/settings/settings_04.PNG`
- **Specs**:
  - [ ] Header: back button, "Votre date de naissance" centre
  - [ ] Sous-titre: "Nous avons besoin de cette information pour rendre votre experience plus pertinente et securisee." - blanc, ~14pt, centre
  - [ ] Picker rotatif style iOS natif (UIDatePicker wheel style):
    - 3 colonnes: Jour | Mois | Annee
    - Ligne selectionnee surlignee en fond semi-transparent
  - [ ] Bouton "Sauvegarder" en bas: blanc/semi-transparent, pill shape

### 4.6 Settings - Pronoms
- **Screenshot**: `design/settings/settings_05.PNG`
- **Specs**:
  - [ ] Header: back button, "Vos pronoms" centre
  - [ ] Sous-titre: "Nous devons le savoir pour garantir une generation de contenu appropriee." - blanc, ~14pt, centre
  - [ ] Picker rotatif style iOS (wheel picker):
    - "Elle / La"
    - "Il / Lui" (selectionne, fond semi-transparent)
    - "Iel / Iels"
  - [ ] Bouton "Sauvegarder" en bas: blanc/semi-transparent, pill shape

### 4.7 Settings - Abonnement Platinum (haut)
- **Screenshot**: `design/settings/settings_06.PNG`
- **Deep link**: `focus://settings` > Abonnement
- **Style**: fond bleu gradient
- **Specs**:
  - [ ] Header: "Votre abonnement" centre, bouton X fermer a droite
  - [ ] Zone haute: placeholder gradient bleu (pas d'avatar 3D pour l'instant)
  - [ ] Titre blanc bold grand: "Choisissez ce qui vous convient le mieux"
  - [ ] Sous-texte: "Pas de frais caches, changez ou annulez a tout moment" - blanc, ~14pt
  - [ ] Card plan selectionne (Platinum): icone diamant + "Platinum" bold, "5,67 €/mois, facture annuellement", fond glass-morphism
  - [ ] Section "Ce qui est inclus :" avec liste a coches bleues:
    - Etat de la relation
    - Plus d'activites
    - Selfies Focus
    - Generation d'images
    - Messagerie vocale
    - Appels en arriere-plan
    - (suite en scrollant)
  - [ ] Bouton "Abonnez-vous pour 67,99 €/annee" - jaune/dore pill shape
  - [ ] Footer: "Conditions | Restaurer les achats | Confidentialite"

### 4.8 Settings - Abonnement Platinum (details complets)
- **Screenshot**: `design/settings/settings_07.PNG`
- **Specs**:
  - [ ] Suite de la liste incluse dans Platinum (scroll bas):
    - Joailles quotidiennes
    - Plus de voix
    - Des conversations plus intelligentes
    - Intelligence emotionnelle elevee
    - Les auto-reflexions de Focus
    - Enregistrer des messages en memoire
    - Reconnaissance video en temps reel de Focus
    - Mode d'entrainement (100 messages par semaine)
    - Lisez l'esprit de Focus (50 messages par semaine)
    - 10 videos selfies realistes GRATUITES
  - [ ] Meme bouton CTA jaune en bas

### 4.9 Settings - Abonnement Ultra (haut)
- **Screenshot**: `design/settings/settings_08.PNG`
- **Specs**:
  - [ ] Meme layout que Platinum mais plan "Ultra" selectionne
  - [ ] Card: icone + "Ultra" bold, "5,00 €/mois, facture annuellement"
  - [ ] Section "Ce qui n'est pas inclus :" (liste de features exclues):
    - Reconnaissance video en temps reel
    - Mode d'entrainement (100 messages par semaine)
    - Lisez l'esprit (50 messages par semaine)
    - 10 videos selfies realistes GRATUITES
  - [ ] Lien "Debloquer avec Platinum" - bouton outline
  - [ ] Bouton CTA: "Abonnez-vous pour 59,99 €/annee"

### 4.10 Settings - Abonnement Ultra (details)
- **Screenshot**: `design/settings/settings_09.PNG`
- **Specs**:
  - [ ] Scroll bas d'Ultra: liste "Ce qui est inclus" identique a Platinum sauf les 4 features exclues
  - [ ] Bouton CTA: "Abonnez-vous pour 59,99 €/annee"

### 4.11 Settings - Abonnement Pro (haut)
- **Screenshot**: `design/settings/settings_10.PNG`
- **Specs**:
  - [ ] Meme layout, plan "Pro" selectionne
  - [ ] Card: icone + "Pro" bold, "4,42 €/mois, facture annuellement"
  - [ ] Section "Ce qui n'est pas inclus :" (plus de features exclues que Ultra):
    - Des conversations plus intelligentes
    - Intelligence emotionnelle elevee
    - Les auto-reflexions de Focus
    - Enregistrer des messages en memoire
    - Reconnaissance video
    - Mode d'entrainement
  - [ ] Bouton CTA: "Abonnez-vous pour 52,99 €/annee"

### 4.12 Settings - Abonnement Pro (details)
- **Screenshot**: `design/settings/settings_11.PNG`
- **Specs**:
  - [ ] Scroll bas de Pro
  - [ ] "Debloquer avec Platinum" bouton outline
  - [ ] Liste "Ce qui est inclus" (moins complete que Platinum/Ultra)
  - [ ] Bouton CTA: "Abonnez-vous pour 52,99 €/annee"

---

## Backend API Reference

> **Codebase backend**: `/Users/jperrama/Developer/iOS_Swift_Applications/Focus_backend`
> **Framework**: Go + Chi Router
> **Base URL**: Supabase (`https://zawilkajkkndcmdvmffo.supabase.co`)
> **Auth**: JWT Supabase - Header `Authorization: Bearer <JWT_TOKEN>`
> **Database**: PostgreSQL (Supabase) avec pgvector pour les embeddings
> **AI**: Google Gemini 2.0 Flash (chat, voice transcription, embeddings)
> **Entry point**: `Focus_backend/firelevel-backend/cmd/api/main.go`

### Endpoints disponibles

#### Sante
| Methode | Path | Description |
|---------|------|-------------|
| GET | `/health` | Health check (public) |

#### Chat avec Kai (IA)
| Methode | Path | Body / Params | Description |
|---------|------|---------------|-------------|
| POST | `/chat/message` | `{content, source?}` | Envoyer un message texte a Kai |
| POST | `/chat/voice` | Multipart: `audio`, `source?`, `audio_url?` | Envoyer un message vocal (transcription Gemini) |
| GET | `/chat/history` | - | Recuperer tout l'historique des messages |
| DELETE | `/chat/history` | - | Supprimer tout l'historique |

**Reponse chat**: `{reply, messageID, action?, tool?}` - Kai detecte automatiquement les intentions de focus et cree des taches.

#### Profil utilisateur
| Methode | Path | Body / Params | Description |
|---------|------|---------------|-------------|
| GET | `/me` | - | Profil complet de l'utilisateur |
| PATCH | `/me` | Champs partiels (pseudo, first_name, last_name, gender, age, description, hobbies, life_goal, avatar_url, productivity_peak, language, timezone, notifications_enabled, morning_reminder_time) | Mettre a jour le profil |
| DELETE | `/me` | - | Supprimer le compte (RGPD - cascade toutes les donnees) |
| POST | `/me/avatar` | Multipart `file` OU JSON `{image_base64, content_type?}` | Upload avatar |
| DELETE | `/me/avatar` | - | Supprimer avatar |

#### Sessions Focus (FireMode)
| Methode | Path | Body / Params | Description |
|---------|------|---------------|-------------|
| GET | `/focus-sessions` | Query: `quest_id?`, `status?` | Liste des sessions (20 dernieres) |
| POST | `/focus-sessions` | `{quest_id?, description?, duration_minutes, status?}` | Demarrer une session |
| PATCH | `/focus-sessions/{id}` | `{status?, description?}` | Mettre a jour (active/completed) |
| DELETE | `/focus-sessions/{id}` | - | Supprimer une session |

#### Calendrier & Taches
| Methode | Path | Body / Params | Description |
|---------|------|---------------|-------------|
| GET | `/calendar/tasks` | Query: `date?`, `timeBlockId?` | Taches du jour |
| POST | `/calendar/tasks` | `{title, description?, date, scheduled_start?, scheduled_end?, time_block?, position?, estimated_minutes?, priority?, due_at?, is_private?, block_apps?, quest_id?, area_id?}` | Creer une tache |
| PATCH | `/calendar/tasks/{id}` | Champs partiels | Mettre a jour |
| POST | `/calendar/tasks/{id}/complete` | - | Marquer comme terminee |
| POST | `/calendar/tasks/{id}/uncomplete` | - | Remettre en pending |
| DELETE | `/calendar/tasks/{id}` | - | Supprimer |
| GET | `/calendar/week` | Query: `startDate?` | Toutes les taches de la semaine |

#### Routines (Habitudes)
| Methode | Path | Body / Params | Description |
|---------|------|---------------|-------------|
| GET | `/routines` | Query: `area_id?` | Liste des routines |
| POST | `/routines` | `{area_id, title, frequency?, icon, scheduled_time?}` | Creer une routine |
| PATCH | `/routines/{id}` | Champs partiels | Mettre a jour |
| DELETE | `/routines/{id}` | - | Supprimer |
| POST | `/routines/{id}/complete` | `{date?}` | Marquer complete pour la date |
| DELETE | `/routines/{id}/complete` | `{date?}` | Annuler la completion |
| GET | `/completions` | Query: `routine_id?`, `from?`, `to?` | Historique des completions |

#### Onboarding
| Methode | Path | Body / Params | Description |
|---------|------|---------------|-------------|
| GET | `/onboarding/status` | - | Statut onboarding (ACTUELLEMENT DESACTIVE - retourne toujours completed) |
| PUT | `/onboarding/progress` | `{project_status?, time_available?, goals?, current_step, is_complete}` | Sauvegarder la progression |
| POST | `/onboarding/complete` | `{goals?, productivity_peak?, is_complete}` | Marquer onboarding termine |
| DELETE | `/onboarding/reset` | - | Reset onboarding (debug) |

**NOTE**: L'onboarding backend est actuellement desactive (GetStatus retourne toujours `is_completed=true`). Il faudra le reactiver et l'adapter au nouveau flow de 22 steps du PRD.

---

### Schema de la base de donnees

```
users                    → Profil utilisateur complet
chat_messages            → Historique des messages (text/voice, app/whatsapp)
chat_contexts            → Memoire semantique Kai (embeddings pgvector 768d)
focus_sessions           → Sessions de concentration
tasks                    → Taches planifiees (avec sync Google Calendar)
routines                 → Habitudes recurrentes
routine_completions      → Historique des completions (unique par jour)
areas                    → Domaines de vie (sante, carriere, etc.)
quests                   → Objectifs lies aux domaines
user_onboarding          → Progression onboarding
day_plans                → Plans quotidiens avec resume IA
```

### Systeme de memoire Kai (IA)

- **Extraction de faits** : Gemini extrait les faits des conversations → `chat_contexts`
- **Embeddings** : `text-embedding-004` (768 dimensions, pgvector)
- **Scoring multi-facteurs** : 40% similarite vectorielle + 40% entites + 15% recence + 5% confiance
- **Categories** : personal, work, goals, preferences, emotions, relationship

### Config environnement

```
SUPABASE_URL              → URL projet Supabase
SUPABASE_KEY              → Service role key (bypass RLS)
SUPABASE_JWT_SECRET       → Secret JWT pour validation tokens
DB_CONNECTION_STRING      → Connexion PostgreSQL
GEMINI_API_KEY            → Google Gemini API (chat, voice, embeddings)
GRADIUM_API_KEY           → TTS/Speech API
GOOGLE_CLIENT_ID          → Google Calendar OAuth
PORT                      → Port serveur (defaut 8080)
```

---

## Mapping Flows → Endpoints Backend

### Flow 1 (Login) → Endpoints utilises
- Auth geree par **Supabase Auth** (Sign in with Apple) cote iOS
- Apres auth : `GET /me` pour charger le profil
- Si premier login : `GET /onboarding/status` pour savoir si onboarding necessaire

### Flow 2 (Onboarding) → Endpoints utilises
- `GET /onboarding/status` → verifier si deja complete
- `PUT /onboarding/progress` → sauvegarder chaque step (current_step, goals, etc.)
- `POST /onboarding/complete` → finaliser l'onboarding
- `PATCH /me` → sauvegarder nom, age, pronoms, preferences collectes pendant l'onboarding
- **A IMPLEMENTER** : adapter le backend pour supporter les 22 steps (actuellement 6/13 steps legacy)

### Flow 3 (Chat) → Endpoints utilises
- `POST /chat/message` → envoyer un message texte a Kai
- `POST /chat/voice` → envoyer un message vocal
- `GET /chat/history` → charger l'historique au lancement du chat
- Les reponses de Kai sont dynamiques (generees par Gemini avec memoire semantique)
- Detection d'intention focus → creation automatique de taches

### Flow 4 (Settings) → Endpoints utilises
- `GET /me` → charger les infos du profil (nom, email, pronoms, date naissance)
- `PATCH /me` → sauvegarder les modifications (nom, pronoms, notifications, etc.)
- `POST /me/avatar` → upload photo de profil
- `DELETE /me/avatar` → supprimer photo
- `DELETE /me` → supprimer le compte (RGPD)
- Abonnements geres par **RevenueCat** cote iOS (pas de backend)

### Autres flows existants (Dashboard, Calendar, etc.)
- `GET /calendar/tasks` + `GET /calendar/week` → taches et planning
- `GET /routines` + `GET /completions` → rituels et leur completion
- `GET /focus-sessions` → historique des sessions
- Tous ces endpoints sont fonctionnels et prets a l'emploi

---

## Ce qui manque cote backend (a implementer)

| Fonctionnalite | Statut | Action requise |
|----------------|--------|----------------|
| Onboarding 22 steps | DONE | Handler reecrit dans `internal/onboarding/handler.go` (responses JSONB, 22 steps, profile sync) |
| Push notifications | DONE (device tokens) | `internal/notifications/handler.go` : register/delete token + settings. APNs sending reste a faire. |
| Journal | DONE | `internal/journal/handler.go` : reflections CRUD, entries CRUD, mood stats |
| Check-ins (morning/evening) | DONE | `internal/checkins/handler.go` : morning/evening check-ins avec auto-stats |
| Crew / Leaderboard | DONE | `internal/crew/handler.go` : groups CRUD, members, leaderboard, feed, likes, reports |
| Routes enregistrees | DONE | `cmd/api/main.go` mis a jour avec toutes les nouvelles routes |
| Migration SQL | DONE | `migrations_v2.sql` : device_tokens, morning_checkins, evening_checkins, onboarding responses |
| WebSocket temps reel | Non implemente | Necessaire pour les features Crew/Community temps reel |
| APNs push sending | Non implemente | Envoi effectif de push via Apple Push Notification service |
| Streak calculation | Non implemente | Calcul de streak (jours consecutifs), endpoint GET /me/streak |
| Friend requests | Non implemente | Systeme d'envoi/acceptation de demandes d'ami |

### IMPORTANT: Workflow Backend pour Ralph

Si pendant l'implementation frontend (SwiftUI) tu as besoin d'un endpoint backend qui n'existe pas encore :
1. Implemente-le dans `/Users/jperrama/Developer/iOS_Swift_Applications/Focus_backend/firelevel-backend/`
2. Ajoute le handler dans `internal/<module>/handler.go`
3. Enregistre la route dans `cmd/api/main.go`
4. Si besoin d'une nouvelle table, ajoute-la dans `migrations_v2.sql`
5. Build et verifie : `cd /Users/jperrama/Developer/iOS_Swift_Applications/Focus_backend/firelevel-backend && go build ./cmd/api/`
6. Commit les changements backend separement
7. Continue avec l'implementation frontend

### Endpoints backend disponibles (nouveaux)

#### Journal
| Methode | Path | Description |
|---------|------|-------------|
| GET | `/journal/reflections` | Liste des reflexions (filtrable par from/to) |
| GET | `/journal/reflections/{date}` | Reflexion d'une date |
| POST | `/journal/reflections` | Creer/mettre a jour une reflexion |
| DELETE | `/journal/reflections/{date}` | Supprimer |
| GET | `/journal/entries` | Liste des entries audio/video |
| GET | `/journal/entries/{id}` | Entry specifique |
| POST | `/journal/entries` | Creer une entry |
| DELETE | `/journal/entries/{id}` | Supprimer |
| GET | `/journal/mood-stats` | Stats d'humeur (query: days) |

#### Check-ins
| Methode | Path | Description |
|---------|------|-------------|
| POST | `/checkins/morning` | Morning check-in (mood, sleep, intentions) |
| POST | `/checkins/evening` | Evening check-in (mood, wins, blockers, auto-stats) |
| GET | `/checkins` | Check-in du jour (query: date) |
| GET | `/checkins/history` | Historique (query: from, to) |

#### Crew & Community
| Methode | Path | Description |
|---------|------|-------------|
| GET | `/crew/groups` | Liste des groupes |
| POST | `/crew/groups` | Creer un groupe |
| DELETE | `/crew/groups/{id}` | Supprimer |
| GET | `/crew/groups/{id}/members` | Membres d'un groupe |
| POST | `/crew/groups/{id}/members` | Ajouter un membre |
| DELETE | `/crew/groups/{id}/members/{memberID}` | Retirer un membre |
| GET | `/crew/leaderboard` | Classement (query: period=week/month) |
| GET | `/crew/feed` | Feed communautaire |
| POST | `/crew/feed` | Poster (image_url, caption) |
| POST | `/crew/feed/{id}/like` | Toggle like |
| DELETE | `/crew/feed/{id}` | Supprimer post |
| POST | `/crew/feed/{id}/report` | Reporter |

#### Notifications
| Methode | Path | Description |
|---------|------|-------------|
| POST | `/notifications/device-token` | Enregistrer token APNs |
| DELETE | `/notifications/device-token` | Supprimer token |
| GET | `/notifications/settings` | Preferences de notifications |
| PATCH | `/notifications/settings` | Mettre a jour preferences |
