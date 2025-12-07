import SwiftUI

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    Group {
                        sectionHeader("Privacy Policy")
                        Text("Last updated: \(formattedDate)")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)

                        Text("Volta (\"we\", \"our\", or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Information We Collect
                    Group {
                        sectionTitle("1. Information We Collect")

                        subsectionTitle("Personal Information")
                        bulletPoint("Name and email address (when you sign in with Apple)")
                        bulletPoint("Profile photo (optional, stored securely)")
                        bulletPoint("Account preferences and settings")

                        subsectionTitle("Usage Data")
                        bulletPoint("Focus session duration and frequency")
                        bulletPoint("Quest and ritual completion data")
                        bulletPoint("App usage patterns and preferences")
                        bulletPoint("Device information (model, OS version)")

                        subsectionTitle("Health & Wellness Data")
                        bulletPoint("Sleep quality ratings (self-reported)")
                        bulletPoint("Mood and feeling check-ins (self-reported)")
                        bulletPoint("Daily intentions and reflections")
                    }

                    // How We Use Your Information
                    Group {
                        sectionTitle("2. How We Use Your Information")
                        bulletPoint("To provide and maintain our service")
                        bulletPoint("To personalize your experience")
                        bulletPoint("To track your progress and streaks")
                        bulletPoint("To send you notifications (with your permission)")
                        bulletPoint("To improve our app and develop new features")
                        bulletPoint("To provide customer support")
                    }

                    // Data Storage & Security
                    Group {
                        sectionTitle("3. Data Storage & Security")
                        Text("Your data is stored securely using industry-standard encryption. We use Supabase as our backend provider, which implements:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        bulletPoint("SSL/TLS encryption for data in transit")
                        bulletPoint("AES-256 encryption for data at rest")
                        bulletPoint("Regular security audits and updates")
                        bulletPoint("Secure authentication via Sign in with Apple")
                    }

                    // Data Sharing
                    Group {
                        sectionTitle("4. Data Sharing")
                        Text("We do NOT sell, trade, or rent your personal information to third parties. We may share data only in the following cases:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        bulletPoint("With your explicit consent")
                        bulletPoint("To comply with legal obligations")
                        bulletPoint("To protect our rights and safety")
                        bulletPoint("With service providers who assist our operations (under strict confidentiality)")
                    }

                    // Your Rights
                    Group {
                        sectionTitle("5. Your Rights")
                        Text("You have the right to:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        bulletPoint("Access your personal data")
                        bulletPoint("Correct inaccurate data")
                        bulletPoint("Delete your account and all associated data")
                        bulletPoint("Export your data in a portable format")
                        bulletPoint("Opt-out of non-essential communications")
                    }

                    // Data Retention
                    Group {
                        sectionTitle("6. Data Retention")
                        Text("We retain your data for as long as your account is active. If you delete your account, we will delete all your personal data within 30 days, except where we are required to retain it for legal purposes.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Children's Privacy
                    Group {
                        sectionTitle("7. Children's Privacy")
                        Text("Volta is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we discover that a child under 13 has provided us with personal information, we will delete it immediately.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Changes to Privacy Policy
                    Group {
                        sectionTitle("8. Changes to This Policy")
                        Text("We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app and updating the \"Last updated\" date.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Contact
                    Group {
                        sectionTitle("9. Contact Us")
                        Text("If you have any questions about this Privacy Policy, please contact us at:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        Text("support@volta.app")
                            .bodyText()
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                }
                .padding(SpacingTokens.lg)
            }
            .background(ColorTokens.background)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    Group {
                        sectionHeader("Terms of Service")
                        Text("Last updated: \(formattedDate)")
                            .caption()
                            .foregroundColor(ColorTokens.textMuted)

                        Text("Please read these Terms of Service (\"Terms\") carefully before using the Volta mobile application operated by Volta (\"us\", \"we\", or \"our\").")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Acceptance of Terms
                    Group {
                        sectionTitle("1. Acceptance of Terms")
                        Text("By accessing or using Volta, you agree to be bound by these Terms. If you disagree with any part of the terms, you may not access the service.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Description of Service
                    Group {
                        sectionTitle("2. Description of Service")
                        Text("Volta is a productivity and habit-tracking application that helps users:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        bulletPoint("Track focus sessions and deep work time")
                        bulletPoint("Set and achieve personal quests and goals")
                        bulletPoint("Build daily rituals and habits")
                        bulletPoint("Monitor progress through levels and streaks")
                        bulletPoint("Connect with a community of builders")
                    }

                    // User Accounts
                    Group {
                        sectionTitle("3. User Accounts")
                        Text("When you create an account with us, you must provide accurate and complete information. You are responsible for:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        bulletPoint("Maintaining the security of your account")
                        bulletPoint("All activities that occur under your account")
                        bulletPoint("Notifying us immediately of any unauthorized use")
                    }

                    // Acceptable Use
                    Group {
                        sectionTitle("4. Acceptable Use")
                        Text("You agree NOT to:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        bulletPoint("Use the service for any illegal purpose")
                        bulletPoint("Harass, abuse, or harm other users")
                        bulletPoint("Attempt to gain unauthorized access to our systems")
                        bulletPoint("Upload malicious code or interfere with the service")
                        bulletPoint("Impersonate others or provide false information")
                        bulletPoint("Use the service in any way that violates these Terms")
                    }

                    // Intellectual Property
                    Group {
                        sectionTitle("5. Intellectual Property")
                        Text("The Volta app, including its original content, features, and functionality, is owned by Volta and is protected by international copyright, trademark, and other intellectual property laws.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)

                        Text("Your content (focus sessions, quests, rituals, reflections) remains yours. By using Volta, you grant us a license to store and display this content to provide the service to you.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                            .padding(.top, SpacingTokens.sm)
                    }

                    // Subscriptions & Payments
                    Group {
                        sectionTitle("6. Subscriptions & Payments")
                        Text("Some features of Volta may require a paid subscription (\"Premium\").")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)

                        subsectionTitle("Billing")
                        bulletPoint("Subscriptions are billed in advance on a recurring basis")
                        bulletPoint("Payment is processed through Apple's App Store")
                        bulletPoint("Prices are subject to change with notice")

                        subsectionTitle("Cancellation")
                        bulletPoint("You may cancel your subscription at any time")
                        bulletPoint("Cancellation takes effect at the end of the current billing period")
                        bulletPoint("No refunds for partial subscription periods")

                        subsectionTitle("Free Trial")
                        bulletPoint("We may offer free trials for Premium features")
                        bulletPoint("You will be charged after the trial unless you cancel")
                    }

                    // Disclaimer of Warranties
                    Group {
                        sectionTitle("7. Disclaimer of Warranties")
                        Text("Volta is provided \"AS IS\" and \"AS AVAILABLE\" without warranties of any kind. We do not guarantee that:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        bulletPoint("The service will be uninterrupted or error-free")
                        bulletPoint("Results from using the service will be accurate")
                        bulletPoint("The service will meet your specific requirements")

                        Text("Volta is a productivity tool and does not provide medical, psychological, or professional advice.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                            .padding(.top, SpacingTokens.sm)
                    }

                    // Limitation of Liability
                    Group {
                        sectionTitle("8. Limitation of Liability")
                        Text("To the maximum extent permitted by law, Volta shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including loss of profits, data, or other intangible losses.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Termination
                    Group {
                        sectionTitle("9. Termination")
                        Text("We may terminate or suspend your account immediately, without prior notice, for any reason, including breach of these Terms. Upon termination:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        bulletPoint("Your right to use the service will cease immediately")
                        bulletPoint("You may request deletion of your data")
                        bulletPoint("Provisions that should survive termination will remain in effect")
                    }

                    // Governing Law
                    Group {
                        sectionTitle("10. Governing Law")
                        Text("These Terms shall be governed by and construed in accordance with the laws of France, without regard to its conflict of law provisions.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Changes to Terms
                    Group {
                        sectionTitle("11. Changes to Terms")
                        Text("We reserve the right to modify these Terms at any time. We will notify users of significant changes through the app or via email. Continued use of the service after changes constitutes acceptance of the new Terms.")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                    }

                    // Contact
                    Group {
                        sectionTitle("12. Contact Us")
                        Text("If you have any questions about these Terms, please contact us at:")
                            .bodyText()
                            .foregroundColor(ColorTokens.textSecondary)
                        Text("support@volta.app")
                            .bodyText()
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                }
                .padding(SpacingTokens.lg)
            }
            .background(ColorTokens.background)
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }
}

// MARK: - Shared Components
private func sectionHeader(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(ColorTokens.textPrimary)
}

private func sectionTitle(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(ColorTokens.textPrimary)
        .padding(.top, SpacingTokens.sm)
}

private func subsectionTitle(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(ColorTokens.textPrimary)
        .padding(.top, SpacingTokens.xs)
}

private func bulletPoint(_ text: String) -> some View {
    HStack(alignment: .top, spacing: SpacingTokens.sm) {
        Text("•")
            .foregroundColor(ColorTokens.primaryStart)
        Text(text)
            .bodyText()
            .foregroundColor(ColorTokens.textSecondary)
    }
    .padding(.leading, SpacingTokens.sm)
}

// MARK: - Previews
#Preview("Privacy Policy") {
    PrivacyPolicyView()
}

#Preview("Terms of Service") {
    TermsOfServiceView()
}
