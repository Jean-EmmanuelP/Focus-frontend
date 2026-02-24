import SwiftUI
import FamilyControls

// MARK: - App Blocker Settings View (Dark Navy style matching SettingsView)

struct AppBlockerSettingsView: View {
    @StateObject private var viewModel = AppBlockerViewModel()
    @ObservedObject private var distractionService = DistractionMonitorService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var showUnblockConfirmation = false

    private let darkNavy = Color(red: 0.102, green: 0.102, blue: 0.306)
    private let chevronColor = Color.white.opacity(0.4)
    private let dividerColor = Color.white.opacity(0.08)
    private let toggleBlue = Color(red: 0.25, green: 0.45, blue: 1.0)

    var body: some View {
        ZStack {
            darkNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Blocage d'apps")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack {
                        Button(action: { dismiss() }) {
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
                    VStack(spacing: 0) {

                        // MARK: - Authorization
                        sectionLabel("Temps d'ecran")

                        HStack {
                            Text("Autorisation")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            Spacer()
                            if viewModel.isAuthorized {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Active")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                }
                            } else {
                                Button(action: {
                                    Task { await viewModel.requestAuthorization() }
                                }) {
                                    if viewModel.isRequestingAuthorization {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.7)
                                    } else {
                                        Text("Autoriser")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(toggleBlue)
                                    }
                                }
                                .disabled(viewModel.isRequestingAuthorization)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)

                        if viewModel.isAuthorized {
                            divider

                            // MARK: - App Selection
                            sectionLabel("Selection")
                                .padding(.top, 16)

                            Button(action: { viewModel.presentAppPicker() }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Apps a bloquer")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        if viewModel.hasSelectedApps {
                                            Text("\(viewModel.selectedAppsCount) selectionnee(s)")
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.5))
                                        } else {
                                            Text("Aucune app selectionnee")
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.35))
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(chevronColor)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                            }

                            if viewModel.hasSelectedApps {
                                divider

                                Button(action: { showClearConfirmation = true }) {
                                    HStack {
                                        Text("Effacer la selection")
                                            .font(.system(size: 16))
                                            .foregroundColor(.red.opacity(0.8))
                                        Spacer()
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red.opacity(0.6))
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                }
                            }

                            // MARK: - Blocking Control
                            sectionLabel("Blocage")
                                .padding(.top, 24)

                            // Toggle bloquer / debloquer
                            HStack {
                                Text("Bloquer les apps")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { viewModel.isBlocking },
                                    set: { newValue in
                                        if newValue {
                                            viewModel.startBlocking()
                                        } else {
                                            showUnblockConfirmation = true
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .tint(toggleBlue)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)

                            // MARK: - Distraction Alert
                            sectionLabel("Alerte distraction")
                                .padding(.top, 24)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Alerte quand j'utilise mes apps")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                    Text("Notification apres 1 min sur une app selectionnee")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { distractionService.distractionMonitorEnabled },
                                    set: { newValue in
                                        distractionService.distractionMonitorEnabled = newValue
                                    }
                                ))
                                .labelsHidden()
                                .tint(toggleBlue)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .opacity(viewModel.hasSelectedApps ? 1.0 : 0.4)
                            .disabled(!viewModel.hasSelectedApps)

                            #if DEBUG
                            if distractionService.distractionMonitorEnabled {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(distractionService.debugInfo)
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange.opacity(0.7))

                                    Button(action: {
                                        distractionService.refreshDebugInfo()
                                    }) {
                                        Text("Rafraichir diagnostic")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                            #endif

                            // MARK: - Unblock Button (visible when blocking)
                            if viewModel.isBlocking {
                                VStack(spacing: 12) {
                                    // Status
                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.shield.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.green)
                                        Text("\(viewModel.selectedAppsCount) app(s) bloquee(s)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.6))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)

                                    // Unblock button
                                    Button(action: { showUnblockConfirmation = true }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "lock.open.fill")
                                                .font(.system(size: 14))
                                            Text("Debloquer toutes les apps")
                                                .font(.system(size: 16, weight: .medium))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(
                                            Capsule().fill(Color.red.opacity(0.25))
                                        )
                                        .overlay(
                                            Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1)
                                        )
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .padding(.top, 20)
                            }
                        }

                        // MARK: - Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ton coach IA peut aussi bloquer et debloquer tes apps depuis le chat.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 32)

                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .familyActivityPicker(
            isPresented: $viewModel.showAppPicker,
            selection: $viewModel.selectedApps
        )
        .onChange(of: viewModel.selectedApps) { _, newValue in
            viewModel.updateSelection(newValue)
        }
        .alert("Autorisation refusee", isPresented: $viewModel.showAuthorizationError) {
            Button("OK", role: .cancel) {}
            Button("Ouvrir Reglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Pour bloquer des apps, autorise l'acces a Temps d'ecran dans les reglages de ton iPhone.")
        }
        .alert("Effacer la selection", isPresented: $showClearConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Effacer", role: .destructive) {
                viewModel.clearSelection()
            }
        } message: {
            Text("Toutes les apps selectionnees seront retirees de la liste de blocage.")
        }
        .alert("Debloquer les apps ?", isPresented: $showUnblockConfirmation) {
            Button("Garder le blocage", role: .cancel) {}
            Button("Debloquer", role: .destructive) {
                viewModel.stopBlocking()
            }
        } message: {
            Text("Le blocage sera desactive immediatement.")
        }
    }

    // MARK: - Components

    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var divider: some View {
        Divider()
            .background(dividerColor)
            .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        AppBlockerSettingsView()
    }
}
