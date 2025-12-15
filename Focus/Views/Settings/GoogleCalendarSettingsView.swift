import SwiftUI
import GoogleSignIn

// MARK: - Google Calendar Settings View
struct GoogleCalendarSettingsView: View {
    @StateObject private var googleService = GoogleCalendarService.shared
    @State private var showDisconnectAlert = false
    @State private var showSyncResult = false
    @State private var syncResult: GoogleSyncResult?
    @State private var isSigningIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Connection Status Card
                connectionStatusCard

                if googleService.config?.isConnected == true {
                    // Sync Settings
                    syncSettingsCard

                    // Sync Now Button
                    syncNowButton

                    // Disconnect Button
                    disconnectButton
                }
            }
            .padding(SpacingTokens.lg)
        }
        .background(ColorTokens.background)
        .navigationTitle("Google Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await googleService.fetchConfig()
            }
        }
        .alert("Déconnecter Google Calendar", isPresented: $showDisconnectAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Déconnecter", role: .destructive) {
                Task {
                    try? await googleService.disconnect()
                }
            }
        } message: {
            Text("Cela arrêtera la synchronisation entre Focus et Google Calendar. Tes événements existants ne seront pas supprimés.")
        }
        .alert("Synchronisation terminée", isPresented: $showSyncResult) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = syncResult {
                Text("\(result.tasksSynced) tâches synchronisées\n\(result.eventsImported) événements importés")
            }
        }
    }

    // MARK: - Connection Status Card
    private var connectionStatusCard: some View {
        VStack(spacing: SpacingTokens.lg) {
            // Icon and Status
            HStack(spacing: SpacingTokens.md) {
                Image("google_calendar_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        // Fallback if image doesn't exist
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Calendar")
                        .font(.satoshi(16, weight: .semibold))
                        .foregroundColor(ColorTokens.textPrimary)

                    if let email = googleService.config?.googleEmail {
                        Text(email)
                            .font(.satoshi(13))
                            .foregroundColor(ColorTokens.textSecondary)
                    } else if googleService.config?.isConnected == true {
                        Text("Connecté")
                            .font(.satoshi(13))
                            .foregroundColor(Color.green)
                    } else {
                        Text("Non connecté")
                            .font(.satoshi(13))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(googleService.config?.isConnected == true ? Color.green : ColorTokens.textMuted)
                    .frame(width: 10, height: 10)
            }

            // Connect/Connected State
            if googleService.config?.isConnected != true {
                // Connect Button
                Button(action: {
                    signInWithGoogle()
                }) {
                    HStack(spacing: SpacingTokens.sm) {
                        if isSigningIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "link")
                        }
                        Text("Connecter Google Calendar")
                    }
                    .font(.satoshi(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#4285F4") ?? .blue, Color(hex: "#34A853") ?? .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(RadiusTokens.md)
                }
                .disabled(isSigningIn)

                Text("Synchronise automatiquement tes tâches et routines avec Google Calendar")
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textMuted)
                    .multilineTextAlignment(.center)
            } else {
                // Last sync info
                if let lastSync = googleService.config?.lastSyncAt {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.satoshi(12))
                            .foregroundColor(ColorTokens.textMuted)
                        Text("Dernière sync: \(formatDate(lastSync))")
                            .font(.satoshi(12))
                            .foregroundColor(ColorTokens.textMuted)
                    }
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Sync Settings Card
    private var syncSettingsCard: some View {
        VStack(spacing: SpacingTokens.md) {
            // Header
            HStack {
                Text("Paramètres de synchronisation")
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textSecondary)
                Spacer()
            }

            // Enable/Disable Toggle
            Toggle(isOn: Binding(
                get: { googleService.config?.isEnabled ?? false },
                set: { newValue in
                    Task {
                        try? await googleService.updateConfig(isEnabled: newValue)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Synchronisation activée")
                        .font(.satoshi(15, weight: .medium))
                        .foregroundColor(ColorTokens.textPrimary)
                    Text("Synchroniser automatiquement les changements")
                        .font(.satoshi(12))
                        .foregroundColor(ColorTokens.textMuted)
                }
            }
            .tint(ColorTokens.primaryStart)

            Divider()
                .background(ColorTokens.border)

            // Sync Direction
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Direction de sync")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textPrimary)

                ForEach(SyncDirection.allCases, id: \.self) { direction in
                    Button(action: {
                        Task {
                            try? await googleService.updateConfig(syncDirection: direction.rawValue)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(direction.title)
                                    .font(.satoshi(14, weight: .medium))
                                    .foregroundColor(ColorTokens.textPrimary)
                                Text(direction.subtitle)
                                    .font(.satoshi(11))
                                    .foregroundColor(ColorTokens.textMuted)
                            }
                            Spacer()
                            if googleService.config?.syncDirection == direction.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ColorTokens.primaryStart)
                            } else {
                                Circle()
                                    .stroke(ColorTokens.border, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(SpacingTokens.sm)
                        .background(
                            googleService.config?.syncDirection == direction.rawValue
                            ? ColorTokens.primaryStart.opacity(0.1)
                            : Color.clear
                        )
                        .cornerRadius(RadiusTokens.sm)
                    }
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    // MARK: - Sync Now Button
    private var syncNowButton: some View {
        Button(action: {
            Task {
                do {
                    let result = try await googleService.syncNow()
                    syncResult = result
                    showSyncResult = true
                    HapticFeedback.success()
                } catch {
                    HapticFeedback.error()
                }
            }
        }) {
            HStack(spacing: SpacingTokens.sm) {
                if googleService.isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(googleService.isSyncing ? "Synchronisation..." : "Synchroniser maintenant")
            }
            .font(.satoshi(15, weight: .semibold))
            .foregroundColor(ColorTokens.primaryStart)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.md)
            .background(ColorTokens.primaryStart.opacity(0.1))
            .cornerRadius(RadiusTokens.md)
        }
        .disabled(googleService.isSyncing || googleService.config?.isEnabled != true)
        .opacity(googleService.config?.isEnabled == true ? 1 : 0.5)
    }

    // MARK: - Disconnect Button
    private var disconnectButton: some View {
        Button(action: {
            showDisconnectAlert = true
        }) {
            HStack(spacing: SpacingTokens.sm) {
                Image(systemName: "link.badge.plus")
                    .rotationEffect(.degrees(45))
                Text("Déconnecter")
            }
            .font(.satoshi(14, weight: .medium))
            .foregroundColor(ColorTokens.error)
        }
        .padding(.top, SpacingTokens.md)
    }

    // MARK: - Google Sign-In
    private func signInWithGoogle() {
        isSigningIn = true

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isSigningIn = false
            return
        }

        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: "613349634589-1d8mmjai794ia29pluv97t21mj2349ej.apps.googleusercontent.com")
        GIDSignIn.sharedInstance.configuration = config

        // Sign in with Calendar scope
        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/calendar"]
        ) { result, error in
            Task { @MainActor in
                isSigningIn = false

                if let error = error {
                    print("[GoogleCalendar] Sign-in error: \(error.localizedDescription)")
                    return
                }

                guard let user = result?.user else {
                    print("[GoogleCalendar] No user returned")
                    return
                }

                let accessToken = user.accessToken.tokenString
                let refreshToken = user.refreshToken.tokenString
                let email = user.profile?.email ?? ""
                let expiresIn = Int(user.accessToken.expirationDate?.timeIntervalSinceNow ?? 3600)

                // Save tokens to backend
                do {
                    try await googleService.saveTokens(
                        accessToken: accessToken,
                        refreshToken: refreshToken,
                        expiresIn: expiresIn,
                        email: email
                    )

                    // Also set tokens locally for direct API calls
                    googleService.setTokens(accessToken: accessToken, refreshToken: refreshToken)

                    HapticFeedback.success()
                    print("[GoogleCalendar] Successfully connected: \(email)")
                } catch {
                    print("[GoogleCalendar] Failed to save tokens: \(error)")
                    HapticFeedback.error()
                }
            }
        }
    }

    // MARK: - Helpers
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sync Direction Enum
enum SyncDirection: String, CaseIterable {
    case bidirectional = "bidirectional"
    case toGoogle = "to_google"
    case fromGoogle = "from_google"

    var title: String {
        switch self {
        case .bidirectional: return "Bidirectionnel"
        case .toGoogle: return "Focus → Google"
        case .fromGoogle: return "Google → Focus"
        }
    }

    var subtitle: String {
        switch self {
        case .bidirectional: return "Synchroniser dans les deux sens"
        case .toGoogle: return "Envoyer les tâches Focus vers Google"
        case .fromGoogle: return "Importer les événements Google dans Focus"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        GoogleCalendarSettingsView()
    }
}
