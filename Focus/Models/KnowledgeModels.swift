import Foundation

// MARK: - Knowledge Models (Replika-style memory system)

/// User's personal profile information that the AI knows
struct UserKnowledge: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String?
    var pronouns: String?
    var birthday: Date?
    var photoURL: String?
    var facts: [KnowledgeFact] = []
}

/// A person the user has told the AI about
struct KnownPerson: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var photoURL: String?
    var category: PersonCategory
    var relation: String?
    var facts: [KnowledgeFact] = []
    var createdAt: Date = Date()

    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

enum PersonCategory: String, Codable, CaseIterable {
    case family = "Famille"
    case partner = "Partenaires"
    case friend = "Amis"
    case colleague = "Collègues"
    case other = "Autre"
}

/// A domain of life the AI knows about
struct LifeDomain: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var imageURL: String?
    var facts: [KnowledgeFact] = []

    var factsCount: Int { facts.count }
}

/// A single fact/memory the AI has learned
struct KnowledgeFact: Codable, Identifiable {
    var id: UUID = UUID()
    var content: String
    var source: FactSource
    var createdAt: Date = Date()
    var isVerified: Bool = false
}

enum FactSource: String, Codable {
    case userProvided = "user"
    case conversationLearned = "conversation"
}

/// Main container for all AI knowledge about the user
struct AIKnowledge: Codable {
    var userProfile: UserKnowledge = UserKnowledge()
    var persons: [KnownPerson] = []
    var lifeDomains: [LifeDomain] = [
        LifeDomain(name: "Carrière"),
        LifeDomain(name: "Bien-être"),
        LifeDomain(name: "Famille"),
        LifeDomain(name: "Loisirs")
    ]

    var totalFacts: Int {
        userProfile.facts.count +
        persons.reduce(0) { $0 + $1.facts.count } +
        lifeDomains.reduce(0) { $0 + $1.facts.count }
    }
}

// MARK: - Pronouns Options

enum PronounsOption: String, CaseIterable {
    case heLui = "Il / Lui"
    case sheElle = "Elle"
    case theyIels = "Iels"
    case other = "Autre"
}

// MARK: - Relation Options

struct RelationOption {
    static let familyRelations = [
        "Parent", "Mère", "Père", "Parent par alliance",
        "Frère", "Sœur", "Demi-frère", "Demi-sœur",
        "Grand-parent", "Grand-mère", "Grand-père",
        "Oncle", "Tante", "Cousin", "Cousine",
        "Enfant", "Fils", "Fille", "Neveu", "Nièce"
    ]

    static let partnerRelations = [
        "Conjoint(e)", "Mari", "Femme",
        "Petit(e) ami(e)", "Partenaire", "Fiancé(e)", "Ex"
    ]

    static let friendRelations = [
        "Meilleur(e) ami(e)", "Ami(e) proche", "Ami(e)", "Connaissance"
    ]

    static let colleagueRelations = [
        "Collègue", "Manager", "Employé(e)", "Mentor",
        "Client", "Partenaire commercial", "Camarade de classe"
    ]
}
