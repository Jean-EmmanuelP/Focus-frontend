import SwiftUI

// MARK: - Create Challenge Flow

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChallenge: SuggestedChallenge?
    @State private var showCustomize = false
    @State private var customAlarmTime = Date()
    @State private var customDuration = 30
    @State private var customMantra = ""
    @State private var customTitle = ""
    @State private var isCreating = false

    var onCreate: (ChallengeType, String, Int, String?, String?, Bool) -> Void

    private let suggestions: [SuggestedChallenge] = [
        SuggestedChallenge(type: .wakeup, title: "Réveil 7h", subtitle: "Devenir matinal", emoji: "🌅", duration: 30, defaultTime: "07:00",
                          gradient: LinearGradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)),
        SuggestedChallenge(type: .gym, title: "Sport quotidien", subtitle: "Forge ton corps", emoji: "💪", duration: 21, defaultTime: nil,
                          gradient: LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)),
        SuggestedChallenge(type: .meditation, title: "Méditation", subtitle: "Calme intérieur", emoji: "🧘", duration: 14, defaultTime: "06:30",
                          gradient: LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)),
        SuggestedChallenge(type: .reading, title: "Lecture 30 min", subtitle: "Un livre par mois", emoji: "📖", duration: 30, defaultTime: "21:00",
                          gradient: LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)),
    ]

    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Invite CTA
                        inviteCard
                            .padding(.top, 8)

                        // Challenge grid
                        VStack(alignment: .leading, spacing: 14) {
                            Text("CHALLENGES")
                                .font(.satoshi(11, weight: .bold))
                                .foregroundColor(ColorTokens.textMuted)
                                .kerning(1.5)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(suggestions) { s in
                                    challengeTile(s)
                                }
                            }
                        }

                        // Custom
                        Button {
                            selectedChallenge = SuggestedChallenge(type: .custom, title: "Personnalisé", subtitle: "Ton propre défi", emoji: "⭐", duration: 30, defaultTime: nil,
                                gradient: LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            showCustomize = true
                        } label: {
                            HStack(spacing: 10) {
                                Text("⭐")
                                    .font(.system(size: 18))
                                Text("Challenge personnalisé")
                                    .font(.satoshi(14, weight: .medium))
                                    .foregroundColor(ColorTokens.textSecondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                            .padding(14)
                            .background(ColorTokens.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Nouveau challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ColorTokens.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(ColorTokens.surface)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showCustomize) {
                if let s = selectedChallenge {
                    customizeSheet(s)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Invite Card

    private var inviteCard: some View {
        Button { shareInviteLink() } label: {
            HStack(spacing: 14) {
                Text("👥")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite un ami")
                        .font(.satoshi(16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Challenge-le pour 30 jours")
                        .font(.satoshi(13, weight: .regular))
                        .foregroundColor(ColorTokens.textSecondary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15))
                    .foregroundColor(ColorTokens.primaryStart)
                    .frame(width: 36, height: 36)
                    .background(ColorTokens.primarySoft)
                    .clipShape(Circle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .fill(ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.lg)
                            .stroke(ColorTokens.borderActive, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Challenge Tile

    private func challengeTile(_ s: SuggestedChallenge) -> some View {
        Button {
            selectedChallenge = s
            showCustomize = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(s.emoji)
                        .font(.system(size: 28))
                    Spacer()
                    Text("\(s.duration)j")
                        .font(.satoshi(11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(s.title)
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(s.subtitle)
                    .font(.satoshi(12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(14)
            .frame(height: 140)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(s.gradient)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Customize Sheet

    private func customizeSheet(_ s: SuggestedChallenge) -> some View {
        NavigationView {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 6) {
                        Text(s.emoji)
                            .font(.system(size: 48))
                        if s.type == .custom {
                            // Editable name for custom challenges
                            TextField("Nom du challenge", text: $customTitle)
                                .font(.satoshi(22, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Text(s.title)
                                .font(.satoshi(22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(s.subtitle)
                            .font(.satoshi(14, weight: .regular))
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    .padding(.top, 16)

                    // Rule explanation
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTokens.primaryStart)
                        Text(ruleExplanation(for: s.type))
                            .font(.satoshi(13, weight: .medium))
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)

                    // Time (if applicable)
                    if s.type == .wakeup || s.type == .meditation {
                        VStack(spacing: 6) {
                            Text("HEURE")
                                .font(.satoshi(11, weight: .bold))
                                .foregroundColor(ColorTokens.textMuted)
                                .kerning(1.5)
                            DatePicker("", selection: $customAlarmTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(height: 100)
                        }
                    }

                    // Duration
                    VStack(spacing: 10) {
                        Text("DURÉE")
                            .font(.satoshi(11, weight: .bold))
                            .foregroundColor(ColorTokens.textMuted)
                            .kerning(1.5)
                        HStack(spacing: 8) {
                            ForEach([7, 14, 21, 30], id: \.self) { d in
                                Button { customDuration = d } label: {
                                    Text("\(d)j")
                                        .font(.satoshi(15, weight: customDuration == d ? .bold : .medium))
                                        .foregroundColor(customDuration == d ? .white : ColorTokens.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(customDuration == d ? AnyShapeStyle(s.gradient) : AnyShapeStyle(ColorTokens.surface))
                                        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Mantra
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MANTRA MATINAL")
                            .font(.satoshi(11, weight: .bold))
                            .foregroundColor(ColorTokens.textMuted)
                            .kerning(1.5)

                        TextField("Ex: Je suis discipliné et aujourd'hui sera une excellente journée", text: $customMantra, axis: .vertical)
                            .font(.satoshi(14, weight: .regular))
                            .foregroundColor(ColorTokens.textPrimary)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(ColorTokens.surface)
                            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))

                        Text("Tu devras le dire 3 fois à voix haute chaque matin")
                            .font(.satoshi(11, weight: .regular))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // CTAs
                    VStack(spacing: 12) {
                        Button {
                            let h = Calendar.current.component(.hour, from: customAlarmTime)
                            let m = Calendar.current.component(.minute, from: customAlarmTime)
                            let mantra = customMantra.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customMantra.trimmingCharacters(in: .whitespaces)
                            let title = s.type == .custom ? (customTitle.isEmpty ? "Challenge" : customTitle) : nil
                            onCreate(s.type, String(format: "%02d:%02d", h, m), customDuration, title, mantra, true)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.plus")
                                Text("Creer et inviter")
                                    .font(.satoshi(16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(s.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg))
                        }

                        Button {
                            let h = Calendar.current.component(.hour, from: customAlarmTime)
                            let m = Calendar.current.component(.minute, from: customAlarmTime)
                            let mantra = customMantra.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customMantra.trimmingCharacters(in: .whitespaces)
                            let title = s.type == .custom ? (customTitle.isEmpty ? "Challenge" : customTitle) : nil
                            onCreate(s.type, String(format: "%02d:%02d", h, m), customDuration, title, mantra, false)
                            dismiss()
                        } label: {
                            Text("Commencer seul")
                                .font(.satoshi(14, weight: .medium))
                                .foregroundColor(ColorTokens.textMuted)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retour") { showCustomize = false }
                        .font(.satoshi(15, weight: .medium))
                        .foregroundColor(ColorTokens.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            customDuration = s.duration
            if let time = s.defaultTime {
                let parts = time.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 {
                    var c = DateComponents(); c.hour = parts[0]; c.minute = parts[1]
                    if let d = Calendar.current.date(from: c) { customAlarmTime = d }
                }
            }
        }
    }

    private func ruleExplanation(for type: ChallengeType) -> String {
        switch type {
        case .wakeup: return "Prends une photo chaque matin dans l'heure qui suit ton reveil. Si tu rates, c'est un jour perdu."
        case .gym: return "Prends une photo a la salle chaque jour. Tu vois ton evolution au fil du temps."
        case .meditation: return "Prends une photo de ta meditation le matin entre 5h et 10h."
        case .reading: return "Prends une photo de ta lecture le soir entre 18h et minuit."
        case .custom: return "Definis ton propre challenge. Une photo par jour pour prouver que tu tiens."
        }
    }

    private func shareInviteLink() {
        let text = "Je te challenge sur Focali ! Prouve que tu peux tenir 30 jours. 💪🔥"
        let url = URL(string: "https://apps.apple.com/app/focali/id6742245252")!
        let ac = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = scene.windows.first?.rootViewController {
            vc.present(ac, animated: true)
        }
    }
}

// MARK: - Model

struct SuggestedChallenge: Identifiable {
    let id = UUID()
    let type: ChallengeType
    let title: String
    let subtitle: String
    let emoji: String
    let duration: Int
    let defaultTime: String?
    let gradient: LinearGradient
}
