import SwiftUI

// MARK: - Challenge Success Celebration

struct ChallengeSuccessView: View {
    let challenge: Challenge
    let dayNumber: Int
    var onDismiss: () -> Void

    @State private var showContent = false
    @State private var showConfetti = false
    @State private var ringProgress: CGFloat = 0
    @State private var scoreScale: CGFloat = 0.5
    @State private var particles: [ConfettiParticle] = []

    private var isMilestone: Bool {
        [7, 14, 21, 30].contains(dayNumber)
    }

    private var milestoneMessage: String {
        switch dayNumber {
        case 7: return "1 semaine !"
        case 14: return "2 semaines !"
        case 21: return "3 semaines — l'habitude est formee"
        case 30: return "30 JOURS — LEGENDAIRE"
        default: return ""
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95).ignoresSafeArea()

            // Confetti particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Success ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [challenge.type.primaryColor.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)

                    // Progress ring
                    Circle()
                        .stroke(challenge.type.primaryColor.opacity(0.15), lineWidth: 8)
                        .frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            challenge.type.gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))

                    // Center content
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(ColorTokens.success)
                        Text("Jour \(dayNumber)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .scaleEffect(scoreScale)
                }
                .padding(.bottom, 32)

                // Title
                if showContent {
                    VStack(spacing: 12) {
                        if isMilestone {
                            Text(milestoneMessage)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(challenge.type.primaryColor)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Valide !")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Text(challenge.type.motivationalLine)
                            .font(.satoshi(15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        // Streak info
                        let streak = challenge.myStreak(myId: FocusAppStore.shared.user?.id ?? "")
                        if streak > 1 {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 16))
                                Text("\(streak) jours de suite")
                                    .font(.satoshi(15, weight: .bold))
                            }
                            .foregroundColor(ColorTokens.warning)
                            .padding(.top, 8)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Dismiss
                if showContent {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Continuer")
                            .font(.satoshi(16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(challenge.type.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.opacity)
                }
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Ring fill
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            let total = Double(challenge.durationDays ?? 30)
            ringProgress = CGFloat(Double(dayNumber) / total)
        }

        // Score pop
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5)) {
            scoreScale = 1.0
        }

        // Content fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            showContent = true
        }

        // Confetti (especially on milestones)
        if isMilestone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                spawnConfetti(count: 40)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                spawnConfetti(count: 15)
            }
        }
    }

    private func spawnConfetti(count: Int) {
        let screenWidth = UIScreen.main.bounds.width
        let colors: [Color] = [
            challenge.type.primaryColor,
            ColorTokens.success,
            ColorTokens.warning,
            ColorTokens.primaryStart,
            .white
        ]

        for i in 0..<count {
            let particle = ConfettiParticle(
                id: UUID(),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 4...10),
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: -20
                ),
                opacity: 1.0
            )
            particles.append(particle)

            // Animate fall
            let delay = Double(i) * 0.03
            withAnimation(.easeIn(duration: Double.random(in: 1.5...3.0)).delay(delay)) {
                if let idx = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[idx].position.y = UIScreen.main.bounds.height + 20
                    particles[idx].position.x += CGFloat.random(in: -60...60)
                    particles[idx].opacity = 0
                }
            }
        }
    }
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id: UUID
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}
