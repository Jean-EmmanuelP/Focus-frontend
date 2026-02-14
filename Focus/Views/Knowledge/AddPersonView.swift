import SwiftUI

/// Add new person view - Replika style
struct AddPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var knowledgeManager = KnowledgeManager.shared

    @State private var name: String = ""
    @State private var selectedCategory: PersonCategory = .family
    @State private var selectedRelation: String = ""
    @State private var showRelationPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                navigationBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Photo section
                        photoSection

                        // Category tabs
                        categoryTabs

                        // Relation field
                        relationField

                        // Name field
                        nameField
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }

                // Create button
                createButton
            }
        }
        .sheet(isPresented: $showRelationPicker) {
            RelationPickerView(
                category: selectedCategory,
                selectedRelation: selectedRelation,
                onSelect: { relation in
                    selectedRelation = relation
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            Text("Nouvelle personne")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 16) {
            // Photo circle with dashed border
            Button(action: {}) {
                ZStack {
                    Circle()
                        .stroke(
                            Color.white.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                        )
                        .frame(width: 160, height: 160)

                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Text("Ajoutez une photo afin que \(FocusAppStore.shared.user?.companionName ?? "ton coach") puisse les reconnaître")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PersonCategory.allCases, id: \.self) { category in
                    categoryTab(category)
                }
            }
        }
    }

    private func categoryTab(_ category: PersonCategory) -> some View {
        Button(action: {
            selectedCategory = category
            selectedRelation = ""
        }) {
            Text(category.rawValue)
                .font(.system(size: 15, weight: selectedCategory == category ? .semibold : .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ? Color.white.opacity(0.15) : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Relation Field

    private var relationField: some View {
        Button(action: { showRelationPicker = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Relation")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                    Text(selectedRelation.isEmpty ? "Sélectionner" : selectedRelation)
                        .font(.system(size: 17))
                        .foregroundColor(selectedRelation.isEmpty ? .white.opacity(0.4) : .white)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    // MARK: - Name Field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $name, prompt: Text("Leur nom").foregroundColor(.white.opacity(0.4)))
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                )
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button(action: createPerson) {
            Text("Créer une personne")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(canCreate ? Color.blue : Color.blue.opacity(0.3))
                )
        }
        .disabled(!canCreate)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createPerson() {
        let person = KnownPerson(
            name: name.trimmingCharacters(in: .whitespaces),
            category: selectedCategory,
            relation: selectedRelation.isEmpty ? nil : selectedRelation
        )
        knowledgeManager.addPerson(person)
        dismiss()
    }
}

// MARK: - Relation Picker View

struct RelationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let category: PersonCategory
    let selectedRelation: String
    let onSelect: (String) -> Void

    var relations: [String] {
        switch category {
        case .family:
            return RelationOption.familyRelations
        case .partner:
            return RelationOption.partnerRelations
        case .friend:
            return RelationOption.friendRelations
        case .colleague:
            return RelationOption.colleagueRelations
        case .other:
            return ["Connaissance", "Autre"]
        }
    }

    var body: some View {
        ZStack {
            Color(white: 0.1).ignoresSafeArea()

            VStack(spacing: 16) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                Text("Relation")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(relations, id: \.self) { relation in
                            Button(action: {
                                onSelect(relation)
                                dismiss()
                            }) {
                                HStack {
                                    Text(relation)
                                        .font(.system(size: 17))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if selectedRelation == relation {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.08))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

#Preview {
    AddPersonView()
}
