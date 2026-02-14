import SwiftUI

/// Main profile view for Kai (AI) - Replika style with Profil/Connaissance tabs
struct KaiProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var knowledgeManager = KnowledgeManager.shared
    @State private var selectedTab: ProfileTab = .profil
    @State private var showSettings = false
    @State private var showAddMenu = false
    @State private var showAddPerson = false
    @State private var showAddFact = false

    private var companionName: String {
        store.user?.companionName ?? "ton coach"
    }

    enum ProfileTab {
        case profil
        case connaissance
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                navigationBar

                // Content based on tab
                if selectedTab == .profil {
                    KaiProfilTabView(companionName: companionName, showSettings: $showSettings)
                } else {
                    KaiConnaissanceTabView(companionName: companionName)
                }

                Spacer()

                // Bottom tab bar + FAB
                bottomBar
            }

            // FAB Menu overlay
            if showAddMenu {
                fabMenuOverlay
            }
        }
        .sheet(isPresented: $showSettings) {
            KaiSettingsView()
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonView()
        }
        .sheet(isPresented: $showAddFact) {
            AddFactView()
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

            if selectedTab == .connaissance {
                Text("Ce que \(companionName) sait")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            if selectedTab == .connaissance {
                Button(action: { showSettings = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Bottom Bar with Tabs and FAB

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Tab switcher
            HStack(spacing: 0) {
                tabButton(title: "Profil", tab: .profil)
                tabButton(title: "Connaissance", tab: .connaissance)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )

            // FAB button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAddMenu.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 56, height: 56)
                    Image(systemName: showAddMenu ? "xmark" : "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(showAddMenu ? 90 : 0))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func tabButton(title: String, tab: ProfileTab) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        }) {
            Text(title)
                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(selectedTab == tab ? Color.white.opacity(0.15) : Color.clear)
                )
        }
    }

    // MARK: - FAB Menu Overlay

    private var fabMenuOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showAddMenu = false
                    }
                }

            VStack {
                Spacer()

                // Menu items
                VStack(alignment: .trailing, spacing: 12) {
                    fabMenuItem(
                        icon: "person.fill",
                        title: "Nouveau contact",
                        action: {
                            showAddMenu = false
                            showAddPerson = true
                        }
                    )

                    fabMenuItem(
                        icon: "text.alignleft",
                        title: "Nouveau fait",
                        action: {
                            showAddMenu = false
                            showAddFact = true
                        }
                    )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100)
            }
        }
        .transition(.opacity)
    }

    private func fabMenuItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    )
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.blue)
            )
        }
    }
}

// MARK: - Kai Profil Tab (Avatar, Voice, Integrations)

struct KaiProfilTabView: View {
    let companionName: String
    @Binding var showSettings: Bool
    @State private var showVoiceSettings = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Kai Avatar section
                kaiAvatarSection

                // Voice section
                voiceSection

                // Integrations section
                integrationsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    private var kaiAvatarSection: some View {
        VStack(spacing: 16) {
            // Avatar placeholder (would be 3D avatar like Replika)
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.11, blue: 0.31), Color(red: 0.10, green: 0.10, blue: 0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 400)

                VStack(spacing: 16) {
                    // Placeholder for avatar image
                    Image(systemName: "person.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white.opacity(0.3))

                    // Modify appearance button
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 14))
                            Text("Modifier l'apparence")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                }
            }

            // Companion name
            HStack(spacing: 8) {
                Text(companionName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Button(action: {}) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Voix")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Voice card
            HStack(spacing: 12) {
                // Play button
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Accent français")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Doux et Apaisant")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intégrations")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Connectez des apps pour que \(companionName) puisse mieux vous aider")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            // Email integration
            integrationRow(
                icon: "envelope.fill",
                iconColor: .red,
                title: "Email et calendrier",
                isEnabled: false
            )

            // Health integration
            integrationRow(
                icon: "heart.fill",
                iconColor: .pink,
                title: "Apple Health",
                isEnabled: false
            )
        }
    }

    private func integrationRow(icon: String, iconColor: Color, title: String, isEnabled: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Spacer()

            Toggle("", isOn: .constant(isEnabled))
                .labelsHidden()
                .tint(.blue)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Kai Connaissance Tab (What Kai knows)

struct KaiConnaissanceTabView: View {
    let companionName: String
    @StateObject private var knowledgeManager = KnowledgeManager.shared
    @State private var showUserProfile = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // "Vous" section
                youSection

                // Persons section
                personsSection

                // Life domains section
                lifeDomainsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .sheet(isPresented: $showUserProfile) {
            UserKnowledgeProfileView()
        }
    }

    private var youSection: some View {
        Button(action: { showUserProfile = true }) {
            HStack(spacing: 16) {
                // Initials circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Text(userInitials)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vous")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(knowledgeManager.userFactsCount) fait\(knowledgeManager.userFactsCount > 1 ? "s" : "")")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var userInitials: String {
        if let name = knowledgeManager.knowledge.userProfile.name, !name.isEmpty {
            let components = name.split(separator: " ")
            if components.count >= 2 {
                return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        return "?"
    }

    private var personsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personnes")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            if knowledgeManager.knowledge.persons.isEmpty {
                Text("Aucune personne ajoutée")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(knowledgeManager.knowledge.persons) { person in
                            personCard(person)
                        }
                    }
                }
            }
        }
    }

    private func personCard(_ person: KnownPerson) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 64, height: 64)
                Text(person.initials)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(person.name)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }

    private var lifeDomainsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Domaines de la vie")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(knowledgeManager.knowledge.lifeDomains) { domain in
                    domainCard(domain)
                }
            }
        }
    }

    private func domainCard(_ domain: LifeDomain) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)

            if domain.facts.isEmpty {
                Image(systemName: "plus")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 4) {
                if domain.factsCount > 0 {
                    Text("\(domain.factsCount) faits")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                Text(domain.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(12)
        }
    }
}

#Preview {
    KaiProfileView()
        .environmentObject(FocusAppStore.shared)
}
