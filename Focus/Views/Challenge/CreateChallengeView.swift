import SwiftUI

// MARK: - Create Challenge Flow

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChallenge: SuggestedChallenge?
    @State private var showCustomize = false
    @State private var customAlarmTime = Date()
    @State private var customDuration = 30
    @State private var isCreating = false

    var onCreate: (ChallengeType, String, Int, String?) -> Void

    private let bgColor = Color(red: 0.10, green: 0.12, blue: 0.20)

    // Pre-built challenge suggestions
    private let suggestions: [SuggestedChallenge] = [
        SuggestedChallenge(
            type: .wakeup,
            title: "Se lever à 7h",
            subtitle: "30 jours pour devenir matinal",
            description: "Prouve chaque matin que tu es debout. L'IA vérifie en live.",
            defaultTime: "07:00",
            duration: 30
        ),
        SuggestedChallenge(
            type: .gym,
            title: "Sport tous les jours",
            subtitle: "21 jours pour créer l'habitude",
            description: "Valide ta séance en live room. Pas de triche possible.",
            defaultTime: nil,
            duration: 21
        ),
        SuggestedChallenge(
            type: .meditation,
            title: "Méditer chaque matin",
            subtitle: "14 jours de calme intérieur",
            description: "5 minutes de méditation pour commencer la journée.",
            defaultTime: "06:30",
            duration: 14
        ),
        SuggestedChallenge(
            type: .reading,
            title: "Lire 30 min par jour",
            subtitle: "30 jours pour lire un livre entier",
            description: "Remplace le scroll par la lecture. Photo de ton livre comme preuve.",
            defaultTime: "21:00",
            duration: 30
        ),
    ]

    var body: some View {
        NavigationView {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero CTA — Invite a friend
                        inviteFriendCard
                            .padding(.top, 8)

                        // Suggested challenges
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Challenges populaires")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .kerning(1)
                                .padding(.horizontal, 4)

                            ForEach(suggestions) { suggestion in
                                challengeCard(suggestion)
                            }
                        }

                        // Custom challenge
                        Button {
                            selectedChallenge = SuggestedChallenge(
                                type: .custom,
                                title: "Mon challenge",
                                subtitle: "Crée ton propre défi",
                                description: "",
                                defaultTime: nil,
                                duration: 30
                            )
                            showCustomize = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Créer un challenge personnalisé")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white.opacity(0.6))
                            .padding(16)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .sheet(isPresented: $showCustomize) {
                if let challenge = selectedChallenge {
                    customizeSheet(challenge)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Invite Friend CTA

    private var inviteFriendCard: some View {
        Button {
            shareInviteLink()
        } label: {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invite un ami")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Text("Challenge-le sur un objectif commun")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Challenge Card

    private func challengeCard(_ suggestion: SuggestedChallenge) -> some View {
        Button {
            selectedChallenge = suggestion
            showCustomize = true
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(suggestion.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: suggestion.type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(suggestion.color)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(suggestion.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()

                // Duration badge
                Text("\(suggestion.duration)j")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(suggestion.color.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(suggestion.color.opacity(0.1))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Customize Sheet

    private func customizeSheet(_ suggestion: SuggestedChallenge) -> some View {
        NavigationView {
            ZStack {
                bgColor.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Challenge info
                    VStack(spacing: 8) {
                        Image(systemName: suggestion.type.icon)
                            .font(.system(size: 36))
                            .foregroundColor(suggestion.color)
                        Text(suggestion.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        if !suggestion.description.isEmpty {
                            Text(suggestion.description)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                    }
                    .padding(.top, 20)

                    // Time picker (for wake-up / meditation)
                    if suggestion.type == .wakeup || suggestion.type == .meditation {
                        VStack(spacing: 8) {
                            Text("Heure")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                            DatePicker("", selection: $customAlarmTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(height: 100)
                        }
                    }

                    // Duration selector
                    VStack(spacing: 8) {
                        Text("Durée du challenge")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        HStack(spacing: 8) {
                            ForEach([7, 14, 21, 30], id: \.self) { days in
                                Button {
                                    customDuration = days
                                } label: {
                                    Text("\(days)j")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(customDuration == days ? .white : .white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule().fill(customDuration == days ? suggestion.color.opacity(0.4) : Color.white.opacity(0.06))
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // CTA buttons
                    VStack(spacing: 10) {
                        // Primary: create + share
                        Button {
                            isCreating = true
                            let h = Calendar.current.component(.hour, from: customAlarmTime)
                            let m = Calendar.current.component(.minute, from: customAlarmTime)
                            let timeStr = String(format: "%02d:%02d", h, m)
                            onCreate(suggestion.type, timeStr, customDuration, suggestion.type == .custom ? suggestion.title : nil)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Créer et inviter un ami")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(suggestion.color)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Secondary: solo
                        Button {
                            isCreating = true
                            let h = Calendar.current.component(.hour, from: customAlarmTime)
                            let m = Calendar.current.component(.minute, from: customAlarmTime)
                            let timeStr = String(format: "%02d:%02d", h, m)
                            onCreate(suggestion.type, timeStr, customDuration, nil)
                            dismiss()
                        } label: {
                            Text("Commencer seul")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Personnaliser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retour") { showCustomize = false }
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            customDuration = suggestion.duration
            if let time = suggestion.defaultTime {
                let parts = time.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 {
                    var components = DateComponents()
                    components.hour = parts[0]
                    components.minute = parts[1]
                    if let date = Calendar.current.date(from: components) {
                        customAlarmTime = date
                    }
                }
            }
        }
    }

    // MARK: - Share

    private func shareInviteLink() {
        let text = "Rejoins-moi sur Focali ! On se challenge pour être plus productifs ensemble. 💪"
        let url = URL(string: "https://apps.apple.com/app/focali/id6742245252")!
        let items: [Any] = [text, url]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(ac, animated: true)
        }
    }
}

// MARK: - Suggested Challenge Model

struct SuggestedChallenge: Identifiable {
    let id = UUID()
    let type: ChallengeType
    let title: String
    let subtitle: String
    let description: String
    let defaultTime: String?
    let duration: Int

    var color: Color {
        switch type {
        case .wakeup: return .orange
        case .gym: return .red
        case .meditation: return .purple
        case .reading: return .blue
        case .custom: return .green
        }
    }
}
