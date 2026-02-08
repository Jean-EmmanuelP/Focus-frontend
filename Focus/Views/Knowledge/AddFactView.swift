import SwiftUI

/// Add new fact view - Replika style modal
struct AddFactView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var knowledgeManager = KnowledgeManager.shared

    @State private var selectedTarget: FactTarget = .user
    @State private var selectedDomain: LifeDomain?
    @State private var factContent: String = ""
    @State private var showTargetPicker = false

    enum FactTarget: String, CaseIterable {
        case user = "Vous"
        case career = "Carrière"
        case wellbeing = "Bien-être"
        case family = "Famille"
        case hobbies = "Loisirs"
    }

    var body: some View {
        ZStack {
            Color(white: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // Title
                Text("À propos")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                Spacer()

                // Target selection
                VStack(spacing: 12) {
                    ForEach(FactTarget.allCases, id: \.self) { target in
                        targetButton(target)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Bottom tabs
                bottomTabs

                // Continue button
                continueButton
            }
        }
        .sheet(isPresented: $showTargetPicker) {
            FactInputView(
                target: selectedTarget,
                onSave: { content in
                    saveFact(content)
                }
            )
        }
    }

    private func targetButton(_ target: FactTarget) -> some View {
        Button(action: {
            selectedTarget = target
            showTargetPicker = true
        }) {
            Text(target.rawValue)
                .font(.system(size: 17, weight: selectedTarget == target ? .semibold : .regular))
                .foregroundColor(selectedTarget == target ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedTarget == target ? Color.white.opacity(0.12) : Color.clear)
                )
        }
    }

    private var bottomTabs: some View {
        HStack(spacing: 8) {
            tabButton(title: "Domaine de vie", isSelected: true)
            tabButton(title: "Personne", isSelected: false)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func tabButton(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }

    private var continueButton: some View {
        Button(action: {
            showTargetPicker = true
        }) {
            Text("Continuer")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func saveFact(_ content: String) {
        switch selectedTarget {
        case .user:
            knowledgeManager.addUserFact(content)
        case .career:
            if let domain = knowledgeManager.knowledge.lifeDomains.first(where: { $0.name == "Carrière" }) {
                knowledgeManager.addFactToDomain(domainId: domain.id, content: content)
            }
        case .wellbeing:
            if let domain = knowledgeManager.knowledge.lifeDomains.first(where: { $0.name == "Bien-être" }) {
                knowledgeManager.addFactToDomain(domainId: domain.id, content: content)
            }
        case .family:
            if let domain = knowledgeManager.knowledge.lifeDomains.first(where: { $0.name == "Famille" }) {
                knowledgeManager.addFactToDomain(domainId: domain.id, content: content)
            }
        case .hobbies:
            if let domain = knowledgeManager.knowledge.lifeDomains.first(where: { $0.name == "Loisirs" }) {
                knowledgeManager.addFactToDomain(domainId: domain.id, content: content)
            }
        }
        dismiss()
    }
}

// MARK: - Fact Input View

struct FactInputView: View {
    @Environment(\.dismiss) private var dismiss
    let target: AddFactView.FactTarget
    let onSave: (String) -> Void

    @State private var content: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("Nouveau fait")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Ajouter") {
                        if !content.isEmpty {
                            onSave(content)
                            dismiss()
                        }
                    }
                    .foregroundColor(content.isEmpty ? .blue.opacity(0.5) : .blue)
                    .fontWeight(.semibold)
                    .disabled(content.isEmpty)
                }
                .padding()

                VStack(alignment: .leading, spacing: 8) {
                    Text("À propos de: \(target.rawValue)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))

                    TextEditor(text: $content)
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .padding(.horizontal)

                Text("Ex: \"Je travaille comme développeur\", \"J'aime le sport\", \"Ma couleur préférée est le bleu\"")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal)

                Spacer()
            }
        }
    }
}

#Preview {
    AddFactView()
}
