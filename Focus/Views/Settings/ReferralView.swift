import SwiftUI

// MARK: - Referral View (Parrainage)
struct ReferralView: View {
    @StateObject private var referralService = ReferralService.shared
    @State private var showShareSheet = false
    @State private var copiedCode = false

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Hero Section
                heroSection

                // Stats Cards
                if let stats = referralService.stats {
                    statsSection(stats: stats)
                }

                // Share Section
                shareSection

                // How it Works
                howItWorksSection

                // Referrals List
                if !referralService.referrals.isEmpty {
                    referralsListSection
                }

                // Earnings History
                if !referralService.earnings.isEmpty {
                    earningsSection
                }
            }
            .padding(SpacingTokens.lg)
        }
        .background(ColorTokens.background)
        .navigationTitle("Parrainage")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await referralService.fetchStats()
            await referralService.fetchReferrals()
            await referralService.fetchEarnings()
        }
        .refreshable {
            await referralService.fetchStats()
            await referralService.fetchReferrals()
            await referralService.fetchEarnings()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [referralService.getShareMessage()])
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Text("🎁")
                    .font(.system(size: 40))
            }

            Text("Invite tes amis, gagne de l'argent !")
                .font(.satoshi(22, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)

            Text("Gagne 20% de commission chaque mois sur les abonnements de tes filleuls")
                .font(.satoshi(14))
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.lg)
        }
        .padding(.vertical, SpacingTokens.xl)
    }

    // MARK: - Stats Section
    private func statsSection(stats: ReferralStats) -> some View {
        HStack(spacing: SpacingTokens.md) {
            // Total Referrals
            StatCard(
                icon: "👥",
                value: "\(stats.totalReferrals)",
                label: "Filleuls"
            )

            // Active Referrals
            StatCard(
                icon: "✅",
                value: "\(stats.activeReferrals)",
                label: "Actifs"
            )

            // Balance
            StatCard(
                icon: "💰",
                value: stats.formattedBalance,
                label: "Solde"
            )
        }
    }

    // MARK: - Share Section
    private var shareSection: some View {
        VStack(spacing: SpacingTokens.md) {
            // Code display
            if referralService.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                    .padding(.vertical, SpacingTokens.lg)
            } else if let code = referralService.stats?.code {
                VStack(spacing: SpacingTokens.sm) {
                    Text("Ton code de parrainage")
                        .font(.satoshi(13))
                        .foregroundColor(ColorTokens.textSecondary)

                    Button {
                        UIPasteboard.general.string = code
                        withAnimation {
                            copiedCode = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                copiedCode = false
                            }
                        }
                    } label: {
                        HStack(spacing: SpacingTokens.sm) {
                            Text(code)
                                .font(.satoshi(24, weight: .bold))
                                .foregroundColor(ColorTokens.primaryStart)

                            Image(systemName: copiedCode ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundColor(copiedCode ? ColorTokens.success : ColorTokens.primaryStart)
                        }
                        .padding(.horizontal, SpacingTokens.xl)
                        .padding(.vertical, SpacingTokens.md)
                        .background(ColorTokens.primarySoft)
                        .cornerRadius(RadiusTokens.lg)
                    }

                    if copiedCode {
                        Text("Code copié !")
                            .font(.satoshi(12, weight: .medium))
                            .foregroundColor(ColorTokens.success)
                    }
                }
            } else if referralService.errorMessage != nil {
                // Error state - show retry
                VStack(spacing: SpacingTokens.sm) {
                    Text("Impossible de charger ton code")
                        .font(.satoshi(14))
                        .foregroundColor(ColorTokens.textSecondary)

                    Button {
                        Task {
                            await referralService.fetchStats()
                        }
                    } label: {
                        Text("Réessayer")
                            .font(.satoshi(14, weight: .semibold))
                            .foregroundColor(ColorTokens.primaryStart)
                    }
                }
                .padding(.vertical, SpacingTokens.md)
            }

            // Share button - only show if we have a code
            if let _ = referralService.stats?.code {
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Partager mon lien")
                    }
                    .font(.satoshi(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.md)
                    .background(
                        LinearGradient(
                            colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(RadiusTokens.lg)
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - How it Works Section
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Comment ca marche ?")
                .font(.satoshi(18, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            VStack(spacing: SpacingTokens.md) {
                HowItWorksStep(
                    number: "1",
                    title: "Partage ton code",
                    description: "Envoie ton code ou lien a tes amis"
                )

                HowItWorksStep(
                    number: "2",
                    title: "Ils s'inscrivent",
                    description: "Tes amis creent un compte avec ton code"
                )

                HowItWorksStep(
                    number: "3",
                    title: "Ils s'abonnent",
                    description: "Quand ils prennent un abonnement, tu gagnes"
                )

                HowItWorksStep(
                    number: "4",
                    title: "Tu gagnes chaque mois",
                    description: "20% de leur abonnement, tant qu'ils restent"
                )
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - Referrals List Section
    private var referralsListSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Tes filleuls")
                .font(.satoshi(18, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            ForEach(referralService.referrals) { referral in
                ReferralRow(referral: referral)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }

    // MARK: - Earnings Section
    private var earningsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Text("Historique des gains")
                    .font(.satoshi(18, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                if let stats = referralService.stats {
                    Text("Total: \(stats.formattedTotalEarned)")
                        .font(.satoshi(14, weight: .semibold))
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }

            ForEach(referralService.earnings) { earning in
                EarningRow(earning: earning)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.xl)
    }
}

// MARK: - Stat Card
private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(icon)
                .font(.system(size: 24))

            Text(value)
                .font(.satoshi(20, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)

            Text(label)
                .font(.satoshi(12))
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }
}

// MARK: - How It Works Step
private struct HowItWorksStep: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.md) {
            // Number circle
            ZStack {
                Circle()
                    .fill(ColorTokens.primarySoft)
                    .frame(width: 32, height: 32)

                Text(number)
                    .font(.satoshi(16, weight: .bold))
                    .foregroundColor(ColorTokens.primaryStart)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text(description)
                    .font(.satoshi(13))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Referral Row
private struct ReferralRow: View {
    let referral: ReferralItem

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Avatar
            if !referral.referredAvatar.isEmpty {
                AsyncImage(url: URL(string: referral.referredAvatar)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(ColorTokens.primarySoft)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(ColorTokens.primarySoft)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(referral.referredName.prefix(1)).uppercased())
                            .font(.satoshi(16, weight: .bold))
                            .foregroundColor(ColorTokens.primaryStart)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(referral.referredName)
                    .font(.satoshi(14, weight: .semibold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Inscrit le \(referral.referredAt)")
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()

            // Status badge
            HStack(spacing: 4) {
                Text(referral.statusEmoji)
                Text(referral.statusText)
                    .font(.satoshi(12, weight: .medium))
                    .foregroundColor(statusColor(for: referral.status))
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, 4)
            .background(statusColor(for: referral.status).opacity(0.1))
            .cornerRadius(RadiusTokens.sm)
        }
        .padding(.vertical, SpacingTokens.xs)
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "active": return ColorTokens.success
        case "pending": return ColorTokens.warning
        case "churned": return ColorTokens.error
        default: return ColorTokens.textMuted
        }
    }
}

// MARK: - Earning Row
private struct EarningRow: View {
    let earning: ReferralEarning

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(earning.referredName)
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textPrimary)

                Text(earning.formattedMonth)
                    .font(.satoshi(12))
                    .foregroundColor(ColorTokens.textSecondary)
            }

            Spacer()

            Text("+\(earning.formattedCommission)")
                .font(.satoshi(14, weight: .bold))
                .foregroundColor(ColorTokens.success)
        }
        .padding(.vertical, SpacingTokens.xs)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ReferralView()
    }
}
