import SwiftUI

struct NearbyUserProfileCard: View {
    let user: NearbyUser
    let matchResult: MatchResult?
    let isProUser: Bool
    let onPaywall: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // MARK: - Free Section (visible to all)
            freeSection

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 12)

            // MARK: - Pro Section (blurred or visible)
            if isProUser {
                proSection
            } else {
                blurredProSection
            }

            Spacer().frame(height: 16)
        }
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#0F1014"))
                .shadow(color: .black.opacity(0.5), radius: 20, y: -5)
        )
    }

    // MARK: - Free Section

    private var freeSection: some View {
        HStack(spacing: 14) {
            // Avatar circle with initial
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 56, height: 56)
                Text(user.initial)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Name + city
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    if let city = user.city {
                        Text("· \(city)")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // Productivity peak + streak
                HStack(spacing: 12) {
                    if let peak = user.productivityPeak {
                        HStack(spacing: 4) {
                            Text(peakEmoji(peak))
                                .font(.system(size: 14))
                            Text(peakLabel(peak))
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    if let streak = user.currentStreak, streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("\(streak)j")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
    }

    // MARK: - Pro Section (unlocked)

    private var proSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Life goal
            if let goal = user.lifeGoal {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Objectif")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(goal)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            // Hobbies tags
            if let hobbies = user.hobbies, !hobbies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Centres d'intérêt")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    FlowLayout(spacing: 6) {
                        ForEach(hobbies.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }, id: \.self) { hobby in
                            Text(hobby)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Steps
            if let steps = user.todaySteps, steps > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                    Text("\(steps.formatted()) pas aujourd'hui")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // AI Match section
            if let match = matchResult, !match.commonPoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#5AC8FA"))
                        Text("Points communs")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#5AC8FA"))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    ForEach(match.commonPoints, id: \.self) { point in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: "#5AC8FA"))
                                .frame(width: 5, height: 5)
                            Text(point)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                }
                .padding(12)
                .background(Color(hex: "#5AC8FA").opacity(0.08))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Blurred Pro Section (paywall)

    private var blurredProSection: some View {
        ZStack {
            // Blurred content placeholder
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 16)
                    .frame(width: 200)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 70, height: 28)
                    }
                }
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#5AC8FA").opacity(0.05))
                    .frame(height: 60)
            }
            .blur(radius: 6)

            // CTA
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
                Text("Voir le profil complet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Button(action: onPaywall) {
                    Text("Débloquer avec Volta Pro")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#5AC8FA"))
                        .cornerRadius(20)
                }
            }
        }
    }

    // MARK: - Helpers

    private var avatarColor: Color {
        let hash = abs(user.displayName.hashValue)
        let colors: [Color] = [
            Color(red: 0.35, green: 0.78, blue: 0.65),
            Color(red: 0.55, green: 0.47, blue: 0.85),
            Color(red: 0.90, green: 0.55, blue: 0.35),
            Color(red: 0.40, green: 0.65, blue: 0.90),
            Color(red: 0.85, green: 0.40, blue: 0.55),
            Color(red: 0.65, green: 0.80, blue: 0.35),
        ]
        return colors[hash % colors.count]
    }

    private func peakEmoji(_ peak: String) -> String {
        switch peak {
        case "morning": return "\u{1F305}"   // sunrise
        case "afternoon": return "\u{2600}\u{FE0F}" // sun
        default: return "\u{1F319}"           // moon
        }
    }

    private func peakLabel(_ peak: String) -> String {
        switch peak {
        case "morning": return "Morning"
        case "afternoon": return "Afternoon"
        default: return "Evening"
        }
    }
}

// Uses FlowLayout from DesignSystem/Components/OtherComponents.swift
