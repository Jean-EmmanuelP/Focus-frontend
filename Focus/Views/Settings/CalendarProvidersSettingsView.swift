import SwiftUI
import GoogleSignIn

struct CalendarProvidersSettingsView: View {
    var onDismiss: () -> Void
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var calendarManager = CalendarProviderManager.shared
    @StateObject private var googleCalService = GoogleCalendarService.shared

    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let background = LinearGradient(
        colors: [
            Color(red: 0.15, green: 0.18, blue: 0.45),
            Color(red: 0.18, green: 0.22, blue: 0.52),
            Color(red: 0.20, green: 0.25, blue: 0.58)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Calendriers")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Button(action: onDismiss) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        googleCalendarSection
                        if calendarManager.hasCalendarConnected {
                            todayEventsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await calendarManager.fetchProviders()
            if calendarManager.hasCalendarConnected {
                await calendarManager.fetchEvents()
            }
            await googleCalService.fetchConfig()
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Google Calendar Section

    private var googleCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Google Calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            VStack(spacing: 0) {
                if googleCalService.config?.isConnected == true {
                    // Connected state
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connecté")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            if let email = googleCalService.config?.googleEmail {
                                Text(email)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)

                    Divider().background(Color.white.opacity(0.08))

                    // Sync button
                    Button(action: {
                        Task {
                            await calendarManager.syncEvents()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.white)
                            Text("Synchroniser maintenant")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            Spacer()
                            if calendarManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .disabled(calendarManager.isLoading)

                    Divider().background(Color.white.opacity(0.08))

                    // Disconnect button
                    Button(action: {
                        Task { await disconnectGoogle() }
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red.opacity(0.8))
                            Text("Déconnecter")
                                .font(.system(size: 15))
                                .foregroundColor(.red.opacity(0.8))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                } else {
                    // Not connected state
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Non connecté")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Connecte ton Google Calendar pour que ton coach voie tes événements")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)

                    Divider().background(Color.white.opacity(0.08))

                    Button(action: { connectGoogle() }) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "link.badge.plus")
                                    .foregroundColor(.blue)
                            }
                            Text("Connecter Google Calendar")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .disabled(isConnecting)
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    // MARK: - Today Events Section

    private var todayEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Événements du jour")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            if calendarManager.todayEvents.isEmpty {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.white.opacity(0.4))
                    Text("Aucun événement aujourd'hui")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(calendarManager.todayEvents.enumerated()), id: \.element.id) { index, event in
                        eventRow(event)
                        if index < calendarManager.todayEvents.count - 1 {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                )
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(_ event: ExternalCalendarEvent) -> some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(spacing: 2) {
                if event.isAllDay {
                    Text("Journée")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                } else if let start = event.startDate {
                    Text(start, style: .time)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 50, alignment: .leading)

            // Event info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if event.eventType == "focusTime" {
                    Text("Focus Time")
                        .font(.system(size: 12))
                        .foregroundColor(.blue.opacity(0.8))
                }
            }

            Spacer()

            // Block apps toggle
            if !event.isAllDay {
                Button(action: {
                    Task {
                        await calendarManager.toggleBlocking(
                            eventId: event.id,
                            enabled: !event.blockApps
                        )
                        // Re-schedule blocking
                        let blockingEvents = calendarManager.todayEvents.filter { $0.blockApps }
                        await CalendarEventBlockingService.shared.scheduleBlockingForEvents(blockingEvents)
                    }
                }) {
                    Image(systemName: event.blockApps ? "lock.fill" : "lock.open")
                        .font(.system(size: 14))
                        .foregroundColor(event.blockApps ? .orange : .white.opacity(0.3))
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Google Sign-In

    private func connectGoogle() {
        isConnecting = true

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isConnecting = false
            errorMessage = "Impossible d'ouvrir Google Sign-In"
            showError = true
            return
        }

        let config = GIDConfiguration(clientID: "613349634589-1d8mmjai794ia29pluv97t21mj2349ej.apps.googleusercontent.com")
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootVC,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/calendar"]
        ) { result, error in
            Task { @MainActor in
                isConnecting = false

                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                    return
                }

                guard let user = result?.user,
                      let accessToken = user.accessToken.tokenString as String?,
                      let email = user.profile?.email else {
                    errorMessage = "Impossible de récupérer les tokens"
                    showError = true
                    return
                }

                let refreshToken = user.refreshToken.tokenString
                let expiresIn = Int(user.accessToken.expirationDate?.timeIntervalSinceNow ?? 3600)

                do {
                    // Save tokens to backend (into calendar_providers table)
                    try await googleCalService.saveTokens(
                        accessToken: accessToken,
                        refreshToken: refreshToken,
                        expiresIn: expiresIn,
                        email: email
                    )

                    // Also set tokens for direct API calls
                    googleCalService.setTokens(accessToken: accessToken, refreshToken: refreshToken)

                    // Trigger initial sync
                    await calendarManager.syncEvents()
                    await calendarManager.fetchProviders()
                } catch {
                    errorMessage = "Erreur de sauvegarde: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func disconnectGoogle() async {
        do {
            try await googleCalService.disconnect()
            GIDSignIn.sharedInstance.signOut()
            await calendarManager.fetchProviders()
            calendarManager.todayEvents = []
        } catch {
            errorMessage = "Erreur de déconnexion: \(error.localizedDescription)"
            showError = true
        }
    }
}
