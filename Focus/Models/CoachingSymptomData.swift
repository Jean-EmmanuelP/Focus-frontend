import Foundation

// MARK: - Coaching Symptom Models

struct CoachingSymptom: Identifiable {
    let id: String
    let label: String
    let description: String
    let coachMessage: String
    let scheduledHour: Int
    let scheduledMinute: Int
    let expectsResponse: Bool
}

struct CoachingCategory: Identifiable {
    let id: String
    let title: String
    let icon: String
    let symptoms: [CoachingSymptom]
}

// MARK: - Static Data

enum CoachingSymptomData {

    static let allCategories: [CoachingCategory] = [

        // 1. La gestion de l'énergie et du focus
        CoachingCategory(
            id: "energy_focus",
            title: "La gestion de l'énergie et du focus",
            icon: "bolt.fill",
            symptoms: [
                CoachingSymptom(
                    id: "fatigue_decisionnelle",
                    label: "La fatigue décisionnelle",
                    description: "S'épuiser à force de devoir choisir quoi faire",
                    coachMessage: "Bonjour. Ton plan est déjà prêt. Ne regarde ni tes mails, ni Slack. Ouvre ton premier dossier et commence. Tu n'as aucune décision à prendre avant 11h. C'est clair ?",
                    scheduledHour: 8, scheduledMinute: 0,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "incapacite_prioriser",
                    label: "L'incapacité à prioriser",
                    description: "Tout traiter avec la même urgence (l'effet \"pompier\")",
                    coachMessage: "Il y a 10 incendies, mais on n'a qu'un seau d'eau. Quelle est l'unique tâche qui, une fois faite, rendrait toutes les autres inutiles ? Donne-moi son nom.",
                    scheduledHour: 9, scheduledMinute: 30,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "dispersion_deep_work",
                    label: "La dispersion (Deep Work impossible)",
                    description: "Être incapable de rester concentré plus de 10 minutes",
                    coachMessage: "On lance un sprint 'Laser'. Pendant 20 minutes, le reste du monde n'existe plus. Pose ton téléphone loin de toi. Je te recontacte à la fin du chrono.",
                    scheduledHour: 10, scheduledMinute: 30,
                    expectsResponse: false
                ),
                CoachingSymptom(
                    id: "multitache_illusoire",
                    label: "Le multitâche illusoire",
                    description: "Sauter d'une app à l'autre en pensant être productif",
                    coachMessage: "Je parie que tu as plus de 5 onglets ouverts. Ferme tout maintenant. Ne garde que ton outil de travail actuel. Envoie-moi une capture d'écran de ton bureau épuré.",
                    scheduledHour: 14, scheduledMinute: 30,
                    expectsResponse: true
                ),
            ]
        ),

        // 2. Les blocages émotionnels
        CoachingCategory(
            id: "emotional_blocks",
            title: "Les blocages émotionnels",
            icon: "heart.fill",
            symptoms: [
                CoachingSymptom(
                    id: "perfectionnisme",
                    label: "Le perfectionnisme paralysant",
                    description: "Ne pas oser finir de peur que ce ne soit pas parfait",
                    coachMessage: "Vise le médiocre pour l'instant. Fais une version moche mais complète. On polira plus tard. C'est fait ?",
                    scheduledHour: 11, scheduledMinute: 0,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "peur_echec",
                    label: "La peur de l'échec (ou du succès)",
                    description: "Saboter son travail pour éviter d'être jugé",
                    coachMessage: "Ta peur te bloque. Écris en une phrase le 'pire' qui puisse arriver. Est-ce vraiment mortel ? Maintenant, avance.",
                    scheduledHour: 14, scheduledMinute: 0,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "syndrome_imposteur",
                    label: "Le syndrome de l'imposteur",
                    description: "Se sentir illégitime, freinant la prise d'initiative",
                    coachMessage: "Ton cerveau te ment. Donne-moi 3 faits concrets où tu as assuré. La légitimité se prouve par les actes.",
                    scheduledHour: 15, scheduledMinute: 30,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "culpabilite_repos",
                    label: "La culpabilité du repos",
                    description: "Incapable de déconnecter sans se sentir mal",
                    coachMessage: "Le repos est ton carburant, pas une récompense. Lâche tout pendant 15 min. Marche ou respire. C'est un ordre.",
                    scheduledHour: 18, scheduledMinute: 0,
                    expectsResponse: false
                ),
            ]
        ),

        // 3. L'organisation et la méthode
        CoachingCategory(
            id: "organization",
            title: "L'organisation et la méthode",
            icon: "list.bullet.clipboard.fill",
            symptoms: [
                CoachingSymptom(
                    id: "surestimation",
                    label: "La surestimation de ses capacités",
                    description: "To-do list impossible à tenir en une journée",
                    coachMessage: "Tu penses que ça prend 1h ? Compte 1h30. Respire, on ne fait pas la course, on vise la précision.",
                    scheduledHour: 9, scheduledMinute: 0,
                    expectsResponse: false
                ),
                CoachingSymptom(
                    id: "absence_systemes",
                    label: "L'absence de systèmes",
                    description: "Dépendre uniquement de la volonté au lieu de routines",
                    coachMessage: "Dès que tu as fini ton café, lance tes 5 min de tri. Ne réfléchis pas, laisse l'habitude piloter.",
                    scheduledHour: 10, scheduledMinute: 45,
                    expectsResponse: false
                ),
                CoachingSymptom(
                    id: "gestion_interruptions",
                    label: "La gestion des interruptions",
                    description: "Ne pas savoir dire non aux sollicitations",
                    coachMessage: "Mets ton casque ou ferme ta porte. Tu n'existes pour personne pendant 1h. Signale-le autour de toi.",
                    scheduledHour: 11, scheduledMinute: 15,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "perte_information",
                    label: "La perte d'information",
                    description: "Pas de système de capture, on cherche ses documents",
                    coachMessage: "Une idée ? Une note ? Ne la laisse pas traîner dans ta tête. Mets-la dans ta boîte de capture. Vide ton esprit.",
                    scheduledHour: 16, scheduledMinute: 30,
                    expectsResponse: false
                ),
            ]
        ),

        // 4. La motivation et le sens
        CoachingCategory(
            id: "motivation",
            title: "La motivation et le sens",
            icon: "flame.fill",
            symptoms: [
                CoachingSymptom(
                    id: "perte_pourquoi",
                    label: "La perte du \"Pourquoi\"",
                    description: "Faire les tâches par automatisme sans vision globale",
                    coachMessage: "Pourquoi tu fais ça déjà ? Rappelle-toi l'impact final de ce projet. Connecte-toi au sens, pas à la corvée.",
                    scheduledHour: 8, scheduledMinute: 45,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "absence_recompense",
                    label: "L'absence de récompense",
                    description: "Ne jamais célébrer les petites victoires",
                    coachMessage: "Tâche validée ! Interdiction de continuer sans une micro-récompense. Café ? Musique ? Étirements ? Fais-le.",
                    scheduledHour: 16, scheduledMinute: 0,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "ennui_repetition",
                    label: "L'ennui sur les tâches répétitives",
                    description: "Difficulté à rester discipliné sur les aspects moins excitants",
                    coachMessage: "C'est l'heure de la tâche robot. Mets ton chrono sur 15 min. Essaie de battre ton record de vitesse. Go !",
                    scheduledHour: 14, scheduledMinute: 0,
                    expectsResponse: false
                ),
            ]
        ),

        // 5. L'environnement et l'hygiène de vie
        CoachingCategory(
            id: "environment",
            title: "L'environnement et l'hygiène de vie",
            icon: "leaf.fill",
            symptoms: [
                CoachingSymptom(
                    id: "desordre",
                    label: "Le désordre physique ou numérique",
                    description: "Bureau encombré créant une charge mentale invisible",
                    coachMessage: "Ton espace reflète ton esprit. Prends 5 minutes pour ranger ton bureau. Un espace clair, un esprit clair.",
                    scheduledHour: 9, scheduledMinute: 15,
                    expectsResponse: false
                ),
                CoachingSymptom(
                    id: "limites_pro_perso",
                    label: "Le manque de limites pro/perso",
                    description: "En télétravail, ne plus savoir quand la journée s'arrête",
                    coachMessage: "Il est l'heure de couper. Ferme ton ordinateur, change de pièce. Ta soirée commence maintenant. Pas de négociation.",
                    scheduledHour: 18, scheduledMinute: 30,
                    expectsResponse: false
                ),
                CoachingSymptom(
                    id: "dependance_outils",
                    label: "La dépendance aux outils",
                    description: "Plus de temps à configurer qu'à travailler réellement",
                    coachMessage: "Stop la configuration. Ton outil est prêt. Ouvre ton projet et travaille dessus pendant 25 minutes sans toucher aux réglages.",
                    scheduledHour: 10, scheduledMinute: 0,
                    expectsResponse: false
                ),
                CoachingSymptom(
                    id: "isolement_social",
                    label: "L'isolement social",
                    description: "Travailler seul trop longtemps, baisse de créativité",
                    coachMessage: "Tu bosses seul depuis trop longtemps. Envoie un message à un collègue ou un ami. 2 minutes de connexion humaine, c'est tout.",
                    scheduledHour: 15, scheduledMinute: 0,
                    expectsResponse: true
                ),
                CoachingSymptom(
                    id: "manque_feedback",
                    label: "Le manque de feedback",
                    description: "Avancer dans le noir sans savoir si c'est efficace",
                    coachMessage: "Tu as avancé aujourd'hui mais est-ce que c'était efficace ? Prends 2 min pour évaluer ta journée sur 10. Qu'est-ce que tu changerais demain ?",
                    scheduledHour: 17, scheduledMinute: 30,
                    expectsResponse: true
                ),
            ]
        ),
    ]

    static func symptomsFor(ids: [String]) -> [CoachingSymptom] {
        let allSymptoms = allCategories.flatMap { $0.symptoms }
        return ids.compactMap { id in allSymptoms.first { $0.id == id } }
    }
}
