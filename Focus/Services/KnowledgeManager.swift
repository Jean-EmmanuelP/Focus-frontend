import Foundation
import SwiftUI
import Combine

/// Manages AI knowledge/memory storage (Replika-style)
/// Stores user profile info, known persons, and life domains that Kai learns about
class KnowledgeManager: ObservableObject {
    static let shared = KnowledgeManager()

    private let userDefaultsKey = "ai_knowledge_data"

    @Published var knowledge: AIKnowledge {
        didSet {
            saveToUserDefaults()
        }
    }

    private init() {
        self.knowledge = KnowledgeManager.loadFromUserDefaults()
    }

    // MARK: - Persistence

    private static func loadFromUserDefaults() -> AIKnowledge {
        guard let data = UserDefaults.standard.data(forKey: "ai_knowledge_data"),
              let decoded = try? JSONDecoder().decode(AIKnowledge.self, from: data) else {
            return AIKnowledge()
        }
        return decoded
    }

    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(knowledge) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    // MARK: - User Profile

    func updateUserName(_ name: String) {
        knowledge.userProfile.name = name.isEmpty ? nil : name
    }

    func updateUserPronouns(_ pronouns: String) {
        knowledge.userProfile.pronouns = pronouns.isEmpty ? nil : pronouns
    }

    func updateUserBirthday(_ date: Date?) {
        knowledge.userProfile.birthday = date
    }

    func updateUserPhoto(_ url: String?) {
        knowledge.userProfile.photoURL = url
    }

    func addUserFact(_ content: String) {
        let fact = KnowledgeFact(content: content, source: .userProvided)
        knowledge.userProfile.facts.append(fact)
    }

    func removeUserFact(at index: Int) {
        guard index < knowledge.userProfile.facts.count else { return }
        knowledge.userProfile.facts.remove(at: index)
    }

    // MARK: - Persons

    func addPerson(_ person: KnownPerson) {
        knowledge.persons.append(person)
    }

    func updatePerson(_ person: KnownPerson) {
        if let index = knowledge.persons.firstIndex(where: { $0.id == person.id }) {
            knowledge.persons[index] = person
        }
    }

    func removePerson(id: UUID) {
        knowledge.persons.removeAll { $0.id == id }
    }

    func addFactToPerson(personId: UUID, content: String) {
        if let index = knowledge.persons.firstIndex(where: { $0.id == personId }) {
            let fact = KnowledgeFact(content: content, source: .userProvided)
            knowledge.persons[index].facts.append(fact)
        }
    }

    // MARK: - Life Domains

    func addLifeDomain(name: String) {
        let domain = LifeDomain(name: name)
        knowledge.lifeDomains.append(domain)
    }

    func updateLifeDomain(_ domain: LifeDomain) {
        if let index = knowledge.lifeDomains.firstIndex(where: { $0.id == domain.id }) {
            knowledge.lifeDomains[index] = domain
        }
    }

    func removeLifeDomain(id: UUID) {
        knowledge.lifeDomains.removeAll { $0.id == id }
    }

    func addFactToDomain(domainId: UUID, content: String) {
        if let index = knowledge.lifeDomains.firstIndex(where: { $0.id == domainId }) {
            let fact = KnowledgeFact(content: content, source: .userProvided)
            knowledge.lifeDomains[index].facts.append(fact)
        }
    }

    // MARK: - Stats

    var userFactsCount: Int {
        knowledge.userProfile.facts.count
    }

    var totalPersons: Int {
        knowledge.persons.count
    }

    var totalFacts: Int {
        knowledge.totalFacts
    }

    // MARK: - Reset

    func resetAllKnowledge() {
        knowledge = AIKnowledge()
    }
}
