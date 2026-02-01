//
//  OnboardingDebugView.swift
//  Focus
//
//  Debug view to test different onboarding flows
//

import SwiftUI

struct OnboardingDebugView: View {
    @EnvironmentObject var store: FocusAppStore
    @State private var showLandingPage = false
    @State private var showNewOnboarding = false
    @State private var showOldOnboarding = false
    @State private var showChatOnboarding = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    // Current auth status
                    HStack {
                        Text("Authentifie")
                        Spacer()
                        Text(store.isAuthenticated ? "Oui" : "Non")
                            .foregroundColor(store.isAuthenticated ? .green : .red)
                    }

                    HStack {
                        Text("Onboarding complete")
                        Spacer()
                        Text(store.hasCompletedOnboarding ? "Oui" : "Non")
                            .foregroundColor(store.hasCompletedOnboarding ? .green : .orange)
                    }

                    if let userId = store.authUserId {
                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(String(userId.prefix(8)) + "...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Etat actuel")
                }

                Section {
                    // New Landing Page
                    Button(action: { showLandingPage = true }) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Landing Page (NOUVEAU)")
                                    .font(.headline)
                                Text("Page d'accueil style Replika")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }

                    // New Onboarding
                    Button(action: { showNewOnboarding = true }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Onboarding leger (NOUVEAU)")
                                    .font(.headline)
                                Text("Flow simplifie: nom, productivite, goals")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Old Onboarding
                    Button(action: { showOldOnboarding = true }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ancien Onboarding")
                                    .font(.headline)
                                Text("14 etapes avec paywall")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Chat Onboarding
                    Button(action: { showChatOnboarding = true }) {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(.green)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chat Onboarding (Perplexity)")
                                    .font(.headline)
                                Text("Chat avec Kai avant login")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Tester les flows")
                }

                Section {
                    // Reset onboarding
                    Button(action: resetOnboarding) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                                .frame(width: 30)

                            Text("Reset Onboarding")
                                .foregroundColor(.red)
                        }
                    }

                    // Sign out
                    if store.isAuthenticated {
                        Button(action: signOut) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                    .frame(width: 30)

                                Text("Se deconnecter")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    Text("Actions")
                }

                Section {
                    Text("Cette vue permet de tester les differents flows d'onboarding sans affecter l'etat reel de l'app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Info")
                }
            }
            .navigationTitle("Debug Onboarding")
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay {
            if showLandingPage {
                LandingPageView()
                    .environmentObject(store)
                    .transition(.opacity)
            }
        }
        .overlay {
            if showNewOnboarding {
                NewOnboardingView()
                    .environmentObject(store)
                    .transition(.opacity)
            }
        }
        .overlay {
            if showOldOnboarding {
                OnboardingView()
                    .environmentObject(store)
                    .transition(.opacity)
            }
        }
        .overlay {
            if showChatOnboarding {
                ChatOnboardingView()
                    .environmentObject(store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showLandingPage)
        .animation(.easeInOut(duration: 0.3), value: showNewOnboarding)
        .animation(.easeInOut(duration: 0.3), value: showOldOnboarding)
        .animation(.easeInOut(duration: 0.3), value: showChatOnboarding)
    }

    private func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "volta_onboarding_completed")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        Task {
            // Call backend to reset
            do {
                try await APIClient.shared.request(
                    endpoint: .onboardingReset,
                    method: .delete
                )
            } catch {
                print("Failed to reset onboarding on backend: \(error)")
            }
        }

        HapticFeedback.success()
    }

    private func signOut() {
        store.signOut()
        HapticFeedback.success()
    }
}

// MARK: - Preview

#Preview {
    OnboardingDebugView()
        .environmentObject(FocusAppStore.shared)
}
