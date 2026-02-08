import SwiftUI
import StoreKit

/// Settings view - Replika style (blue gradient background)
struct KaiSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false

    var body: some View {
        ZStack {
            // Blue gradient background like Replika
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.45),
                    Color(red: 0.08, green: 0.08, blue: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Paramètres")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        // Main settings
                        VStack(spacing: 0) {
                            settingsToggle(title: "Notifications", isOn: $notificationsEnabled)
                            Divider().background(Color.white.opacity(0.1))
                            settingsToggle(title: "Face ID", isOn: $faceIDEnabled)
                        }

                        // Resources section
                        resourcesSection

                        // Community section
                        communitySection

                        // Logout button
                        logoutButton

                        // Version
                        Text("Version \(appVersion)")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Settings Toggle

    private func settingsToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.blue)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ressources")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                linkRow(title: "Centre d'aide", url: "https://help.example.com")
                Divider().background(Color.white.opacity(0.1))
                linkRow(title: "Évaluez-nous", action: requestReview)
                Divider().background(Color.white.opacity(0.1))
                linkRow(title: "Conditions d'utilisation", url: "https://example.com/terms")
                Divider().background(Color.white.opacity(0.1))
                linkRow(title: "Politique de confidentialité", url: "https://example.com/privacy")
                Divider().background(Color.white.opacity(0.1))
                linkRow(title: "Crédits", url: "https://example.com/credits")
            }
        }
    }

    // MARK: - Community Section

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Rejoignez notre communauté")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                socialLinkRow(
                    icon: "bubble.left.fill",
                    iconColor: .orange,
                    title: "Reddit",
                    url: "https://reddit.com"
                )
                Divider().background(Color.white.opacity(0.1))
                socialLinkRow(
                    icon: "message.fill",
                    iconColor: Color(red: 0.4, green: 0.4, blue: 0.9),
                    title: "Discord",
                    url: "https://discord.com"
                )
                Divider().background(Color.white.opacity(0.1))
                socialLinkRow(
                    icon: "f.square.fill",
                    iconColor: .blue,
                    title: "Facebook",
                    url: "https://facebook.com"
                )
            }
        }
    }

    // MARK: - Link Row

    private func linkRow(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 16)
        }
    }

    private func linkRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 16)
        }
    }

    private func socialLinkRow(icon: String, iconColor: Color, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 14)
        }
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button(action: {
            // Handle logout
        }) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18))
                Text("Se déconnecter")
                    .font(.system(size: 17))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
            )
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version).\(build)"
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}

#Preview {
    KaiSettingsView()
}
