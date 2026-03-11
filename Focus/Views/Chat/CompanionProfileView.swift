import SwiftUI

// MARK: - Companion Profile View

struct CompanionProfileView: View {
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: FocusAppStore
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    private let userService = UserService()

    // Use store values with fallbacks
    private var companionName: String {
        store.user?.companionName ?? "ton coach"
    }
    private var companionGender: String {
        switch store.user?.companionGender {
        case "male": return "Homme"
        case "female": return "Femme"
        case "non-binary": return "Non-binaire"
        default: return "Homme"
        }
    }

    @State private var selectedRelation: String = "Ami"

    @State private var showEditNameGender = false
    @State private var showVoiceSelection = false
    @State private var showPaywall = false

    // Temp values for editing
    @State private var tempName: String = ""
    @State private var tempGender: String = ""
    @State private var isSaving = false

    // Memories
    @State private var memories: [BackboardMemory] = []
    @State private var isLoadingMemories = true
    @State private var showAddMemory = false

    // Voice
    @State private var selectedVoiceId: String = UserDefaults.standard.string(forKey: SettingsPrefsKeys.voltaVoiceId) ?? "b35yykvVppLXyw_l"

    // Animated gradient
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Animated blue gradient background
            animatedBackground
                .ignoresSafeArea()

            // Profile page
                VStack(spacing: 0) {
                    // Header with back button (changes when editing)
                    if showEditNameGender {
                        editHeader
                    } else {
                        header
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Avatar placeholder
                            avatarSection

                            // Name and gender (or edit card when editing)
                            if showEditNameGender {
                                editNameGenderCard
                            } else {
                                nameSection
                            }

                            // Only show other sections when NOT editing
                            if !showEditNameGender {
                                // Relation section
                                relationSection

                                // Memories section
                                memoriesSection

                                // Voice section
                                voiceSection

                                // Footer
                                footerSection
                            }

                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 20)
                    }
                }

            // Paywall overlay
            if showPaywall {
                FocusPaywallView(
                    companionName: companionName,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPaywall = false
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPaywall = false
                        }
                    }
                )
                .environmentObject(subscriptionManager)
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.3), value: showEditNameGender)
        .animation(.easeInOut(duration: 0.3), value: showPaywall)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
            loadMemories()
        }
        .sheet(isPresented: $showVoiceSelection) {
            VoltaVoicePickerView(
                currentVoiceId: selectedVoiceId,
                coachName: companionName,
                onDismiss: { showVoiceSelection = false },
                onSave: { voiceId in
                    selectedVoiceId = voiceId
                    UserDefaults.standard.set(voiceId, forKey: SettingsPrefsKeys.voltaVoiceId)
                    showVoiceSelection = false
                    Task {
                        try? await userService.updateSettings(voiceId: voiceId)
                    }
                }
            )
        }
        .sheet(isPresented: $showAddMemory) {
            AddMemorySheet(
                onSave: { content in
                    showAddMemory = false
                    Task {
                        try? await BackboardService.shared.addMemory(content: content)
                        loadMemories()
                    }
                },
                onCancel: { showAddMemory = false }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Load Memories

    private func loadMemories() {
        Task {
            isLoadingMemories = true
            do {
                memories = try await BackboardService.shared.listMemories()
            } catch {
                print("Failed to load memories: \(error)")
            }
            isLoadingMemories = false
        }
    }

    private func deleteMemory(_ memory: BackboardMemory) {
        Task {
            do {
                try await BackboardService.shared.deleteMemory(id: memory.id)
                memories.removeAll { $0.id == memory.id }
            } catch {
                print("Failed to delete memory: \(error)")
            }
        }
    }

    // MARK: - Animated Background (Replika style - vibrant blue)

    private var animatedBackground: some View {
        ZStack {
            // Base: Vibrant saturated blue (exact Replika color)
            Color(red: 0.22, green: 0.50, blue: 1.0)

            // Top gradient overlay (lighter blue at top)
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.60, blue: 1.0).opacity(0.7),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            // Center glow (white/light that creates the "light" effect)
            RadialGradient(
                colors: [
                    Color.white.opacity(animateGradient ? 0.25 : 0.15),
                    Color.white.opacity(animateGradient ? 0.08 : 0.03),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: animateGradient ? 450 : 400
            )
            .offset(y: animateGradient ? -40 : 40)

            // Bottom gradient (slightly darker blue)
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.18, green: 0.40, blue: 0.85).opacity(0.4)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Edit Header (when editing name/gender)

    private var editHeader: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showEditNameGender = false
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            Spacer()
            Text("Nom & genre")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Edit Name Gender Card (light frosted glass blur like Replika)

    private var editNameGenderCard: some View {
        VStack(spacing: 20) {
            // Name text field - WHITE text
            HStack {
                TextField("Nom", text: $tempName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
                    .accentColor(.white)

                Button(action: {
                    Task {
                        await saveCompanionSettings()
                    }
                }) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white)
                            )
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white)
                            )
                    }
                }
                .disabled(isSaving)
            }

            // Gender chips - all on one line, white text
            HStack(spacing: 10) {
                GenderChipBlur(title: "Non-binaire", isSelected: tempGender == "Non-binaire") {
                    tempGender = "Non-binaire"
                }
                GenderChipBlur(title: "Homme", isSelected: tempGender == "Homme") {
                    tempGender = "Homme"
                }
                GenderChipBlur(title: "Femme", isSelected: tempGender == "Femme") {
                    tempGender = "Femme"
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.15))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                )
        )
        .padding(.top, 60)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        // 3D Avatar from Ready Player Me
        AvatarCardView(
            gender: store.user?.companionGender,
            height: 350,
            showEditButton: false,
            onEditTap: {}
        )
        .padding(.top, 20)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(spacing: 4) {
            Button(action: {
                tempName = companionName
                tempGender = companionGender
                withAnimation(.easeInOut(duration: 0.25)) {
                    showEditNameGender = true
                }
            }) {
                HStack(spacing: 8) {
                    Text(companionName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Text(companionGender)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Relation Section

    private var relationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Relation")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    RelationChip(title: "Ami", isSelected: selectedRelation == "Ami", isLocked: false) {
                        selectedRelation = "Ami"
                    }
                    RelationChip(title: "Petit ami", isSelected: selectedRelation == "Petit ami", isLocked: true) {}
                    RelationChip(title: "Mari", isSelected: selectedRelation == "Mari", isLocked: true) {}
                    RelationChip(title: "Frère", isSelected: selectedRelation == "Frère", isLocked: true) {}
                    RelationChip(title: "Mentor", isSelected: selectedRelation == "Mentor", isLocked: true) {}
                }
            }
        }
    }

    // MARK: - Memories Section

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mémoires")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showAddMemory = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }

            if isLoadingMemories {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .padding(20)
            } else if memories.isEmpty {
                // Empty state card
                VStack(spacing: 12) {
                    Text("Rien ici pour l'instant")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Apprendre à se connaître est passionnant. \(companionName) se souviendra toujours de ce qui est important pour vous.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button(action: { showAddMemory = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Ajouter")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.15, green: 0.25, blue: 0.45).opacity(0.6))
                )
            } else {
                // Memories list
                VStack(spacing: 8) {
                    ForEach(memories) { memory in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 2)

                            Text(memory.content)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(3)

                            Spacer()

                            Button(action: { deleteMemory(memory) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                    )
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Voix")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showVoiceSelection = true }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }

            // Current voice card
            Button(action: { showVoiceSelection = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }

                    Text(VoltaVoicePickerView.voiceName(for: selectedVoiceId))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
    }


    // MARK: - Footer Section

    private var daysSinceCreation: Int {
        guard let createdAt = store.user?.createdAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }

    private var footerSection: some View {
        VStack(spacing: 16) {
            Text("\(companionName) et vous vous êtes rencontrés il y a \(daysSinceCreation) jour\(daysSinceCreation > 1 ? "s" : "")")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            // App logo placeholder
            Image(systemName: "person.2.fill")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(.top, 20)
    }

    // MARK: - Save Companion Settings

    private func saveCompanionSettings() async {
        isSaving = true
        defer { isSaving = false }

        // Convert display gender to API format
        let genderValue: String
        switch tempGender {
        case "Homme": genderValue = "male"
        case "Femme": genderValue = "female"
        case "Non-binaire": genderValue = "non-binary"
        default: genderValue = "male"
        }

        do {
            let updated = try await userService.updateProfile(
                companionName: tempName,
                companionGender: genderValue
            )
            await MainActor.run {
                FocusAppStore.shared.user = User(from: updated)
                withAnimation(.easeInOut(duration: 0.25)) {
                    showEditNameGender = false
                }
            }
            // Recreate assistant so the new companion name is reflected in the system prompt
            await BackboardService.shared.recreateAssistant()
        } catch {
            print("Failed to save companion settings: \(error)")
            // Still close the sheet even on error
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showEditNameGender = false
                }
            }
        }
    }
}

// MARK: - Relation Chip

struct RelationChip: View {
    let title: String
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .disabled(isLocked)
    }
}

// Gender chip for the edit card (dark gray with white text, like Replika)
struct GenderChipBlur: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(Color(white: 0.35).opacity(0.6))
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1.5)
                        )
                )
        }
    }
}

// MARK: - Add Memory Sheet

struct AddMemorySheet: View {
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Ajouter une mémoire")
                    .font(.system(size: 20, weight: .bold))

                Text("Dites quelque chose que votre coach devrait retenir à propos de vous.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextEditor(text: $text)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .focused($isFocused)

                Button(action: {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                }) {
                    Text("Enregistrer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        )
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onCancel() }
                }
            }
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - Preview

#Preview("Companion Profile") {
    CompanionProfileView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(SubscriptionManager.shared)
}
