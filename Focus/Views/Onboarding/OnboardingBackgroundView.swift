//
//  OnboardingBackgroundView.swift
//  Focus
//
//  Atmospheric background with portal scene and floating particles
//

import SwiftUI

// MARK: - Vue principale du fond d'écran
struct OnboardingBackgroundView: View {
    var body: some View {
        ZStack {
            // Fond dégradé principal
            BackgroundGradient()

            // Orbes flottantes atmosphériques
            FloatingOrbs()

            // Particules / étoiles qui montent
            RisingParticles()

            // Lueur chaude derrière la scène
            SceneGlow()

            // Scène SVG (silhouettes + portail)
            SceneView()
                .frame(width: 360, height: 340)
                .offset(y: -20)
        }
        .ignoresSafeArea()
        .background(Color(red: 0.04, green: 0.055, blue: 0.1))
    }
}

// MARK: - Fond dégradé
private struct BackgroundGradient: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.024, green: 0.04, blue: 0.08),
                    Color(red: 0.047, green: 0.07, blue: 0.145),
                    Color(red: 0.06, green: 0.1, blue: 0.18),
                    Color(red: 0.024, green: 0.04, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Radial bleu
            RadialGradient(
                colors: [
                    Color(red: 0.08, green: 0.235, blue: 0.353).opacity(0.7),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )

            // Radial violet
            RadialGradient(
                colors: [
                    Color(red: 0.157, green: 0.08, blue: 0.314).opacity(0.5),
                    Color.clear
                ],
                center: UnitPoint(x: 0.3, y: 0.45),
                startRadius: 0,
                endRadius: 250
            )
        }
    }
}

// MARK: - Orbes flottantes
private struct FloatingOrbs: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.39, green: 0.55, blue: 1.0).opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -80, y: animate ? -40 : 0)
                .opacity(animate ? 1 : 0)

            Circle()
                .fill(Color(red: 0.7, green: 0.39, blue: 1.0).opacity(0.1))
                .frame(width: 160, height: 160)
                .blur(radius: 60)
                .offset(x: 80, y: animate ? -60 : -20)
                .opacity(animate ? 1 : 0)

            Circle()
                .fill(Color(red: 0.235, green: 0.78, blue: 0.7).opacity(0.08))
                .frame(width: 120, height: 120)
                .blur(radius: 60)
                .offset(x: -20, y: animate ? 80 : 120)
                .opacity(animate ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Particules qui montent (étoiles)
private struct RisingParticles: View {
    let particleCount = 15

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<particleCount, id: \.self) { index in
                SingleParticle(
                    screenHeight: geo.size.height,
                    screenWidth: geo.size.width,
                    index: index
                )
            }
        }
    }
}

private struct SingleParticle: View {
    let screenHeight: CGFloat
    let screenWidth: CGFloat
    let index: Int

    @State private var yOffset: CGFloat = 0
    @State private var xDrift: CGFloat = 0
    @State private var opacity: Double = 0

    // Propriétés aléatoires par particule
    private var startX: CGFloat {
        CGFloat.random(in: 0...1) * screenWidth
    }
    private var startY: CGFloat {
        screenHeight * CGFloat.random(in: 0.5...0.95)
    }
    private var size: CGFloat {
        CGFloat.random(in: 1.5...3.5)
    }
    private var duration: Double {
        Double.random(in: 8...16)
    }
    private var delay: Double {
        Double.random(in: 0...8)
    }
    private var drift: CGFloat {
        CGFloat.random(in: -40...40)
    }
    private var travelDistance: CGFloat {
        CGFloat.random(in: 300...500)
    }

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.4))
            .frame(width: size, height: size)
            .shadow(color: .white.opacity(0.3), radius: 2)
            .position(x: startX + xDrift, y: startY + yOffset)
            .opacity(opacity)
            .onAppear {
                startAnimation()
            }
    }

    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateCycle()
        }
    }

    private func animateCycle() {
        yOffset = 0
        xDrift = 0
        opacity = 0

        withAnimation(.easeIn(duration: duration * 0.1)) {
            opacity = 1
        }

        withAnimation(.linear(duration: duration)) {
            yOffset = -travelDistance
            xDrift = drift
        }

        withAnimation(.easeOut(duration: duration * 0.15).delay(duration * 0.85)) {
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
            animateCycle()
        }
    }
}

// MARK: - Lueur chaude derrière la scène
private struct SceneGlow: View {
    @State private var glowPulse = false

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.7, blue: 0.39).opacity(0.12),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 140
                )
            )
            .frame(width: 280, height: 240)
            .blur(radius: 30)
            .opacity(glowPulse ? 1 : 0.6)
            .offset(y: -30)
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
    }
}

// MARK: - Scène principale (portail + silhouettes)
private struct SceneView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // -- Étoiles fixes dans le ciel --
            let stars: [(CGFloat, CGFloat, CGFloat)] = [
                (0.14, 0.09, 2.0),
                (0.33, 0.04, 1.6),
                (0.67, 0.07, 2.4),
                (0.83, 0.12, 1.4),
                (0.50, 0.06, 2.0),
                (0.22, 0.18, 1.2),
                (0.78, 0.21, 1.8)
            ]
            for (sx, sy, sr) in stars {
                let starRect = CGRect(
                    x: w * sx - sr/2,
                    y: h * sy - sr/2,
                    width: sr,
                    height: sr
                )
                context.fill(
                    Path(ellipseIn: starRect),
                    with: .color(.white.opacity(0.35))
                )
            }

            // -- Portail lumineux (ellipse) --
            let portalRect = CGRect(
                x: w * 0.19,
                y: h * 0.0,
                width: w * 0.62,
                height: h * 0.9
            )
            context.fill(
                Path(ellipseIn: portalRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1, green: 0.82, blue: 0.55).opacity(0.4),
                        Color(red: 0.78, green: 0.63, blue: 1).opacity(0.15),
                        Color.clear
                    ]),
                    center: CGPoint(x: w * 0.5, y: h * 0.44),
                    startRadius: 0,
                    endRadius: w * 0.35
                )
            )

            // -- Source lumineuse au loin --
            let lightCenter = CGPoint(x: w * 0.5, y: h * 0.19)

            let bigLight = CGRect(
                x: lightCenter.x - 35,
                y: lightCenter.y - 35,
                width: 70, height: 70
            )
            context.fill(
                Path(ellipseIn: bigLight),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1, green: 0.88, blue: 0.63).opacity(0.25),
                        Color.clear
                    ]),
                    center: lightCenter,
                    startRadius: 0,
                    endRadius: 35
                )
            )

            let coreLight = CGRect(
                x: lightCenter.x - 6,
                y: lightCenter.y - 6,
                width: 12, height: 12
            )
            context.fill(
                Path(ellipseIn: coreLight),
                with: .color(Color(red: 1, green: 0.98, blue: 0.9).opacity(0.5))
            )

            // -- Chemin lumineux au sol --
            var lightPath = Path()
            lightPath.move(to: CGPoint(x: w * 0.36, y: h * 0.91))
            lightPath.addQuadCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.5),
                control: CGPoint(x: w * 0.43, y: h * 0.68)
            )
            lightPath.addQuadCurve(
                to: CGPoint(x: w * 0.64, y: h * 0.91),
                control: CGPoint(x: w * 0.57, y: h * 0.68)
            )
            lightPath.closeSubpath()
            context.fill(
                lightPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1, green: 0.82, blue: 0.55).opacity(0.35),
                        Color(red: 1, green: 0.78, blue: 0.47).opacity(0)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: h * 0.5),
                    endPoint: CGPoint(x: w * 0.5, y: h * 0.91)
                )
            )

            // -- Figure humaine (gauche) --
            let fig1Color = Color(red: 0.11, green: 0.11, blue: 0.24)
            let f1x: CGFloat = w * 0.375
            let f1y: CGFloat = h * 0.34

            // Tête
            context.fill(
                Path(ellipseIn: CGRect(x: f1x, y: f1y, width: 24, height: 24)),
                with: .color(fig1Color)
            )
            // Cheveux
            var hair = Path()
            hair.move(to: CGPoint(x: f1x + 2, y: f1y + 6))
            hair.addQuadCurve(to: CGPoint(x: f1x + 10, y: f1y - 6), control: CGPoint(x: f1x - 2, y: f1y - 4))
            hair.addQuadCurve(to: CGPoint(x: f1x + 20, y: f1y + 2), control: CGPoint(x: f1x + 16, y: f1y - 8))
            hair.addQuadCurve(to: CGPoint(x: f1x + 2, y: f1y + 6), control: CGPoint(x: f1x + 22, y: f1y + 8))
            context.fill(hair, with: .color(fig1Color))

            // Corps
            var body1 = Path()
            body1.move(to: CGPoint(x: f1x + 4, y: f1y + 22))
            body1.addQuadCurve(to: CGPoint(x: f1x + 2, y: f1y + 50), control: CGPoint(x: f1x + 1, y: f1y + 35))
            body1.addLine(to: CGPoint(x: f1x, y: f1y + 100))
            body1.addLine(to: CGPoint(x: f1x + 10, y: f1y + 104))
            body1.addLine(to: CGPoint(x: f1x + 12, y: f1y + 72))
            body1.addQuadCurve(to: CGPoint(x: f1x + 16, y: f1y + 72), control: CGPoint(x: f1x + 14, y: f1y + 64))
            body1.addLine(to: CGPoint(x: f1x + 18, y: f1y + 104))
            body1.addLine(to: CGPoint(x: f1x + 28, y: f1y + 100))
            body1.addLine(to: CGPoint(x: f1x + 26, y: f1y + 50))
            body1.addQuadCurve(to: CGPoint(x: f1x + 20, y: f1y + 22), control: CGPoint(x: f1x + 25, y: f1y + 35))
            body1.closeSubpath()
            context.fill(body1, with: .color(fig1Color))

            // Bras tendu
            var arm1 = Path()
            arm1.move(to: CGPoint(x: f1x + 22, y: f1y + 32))
            arm1.addQuadCurve(
                to: CGPoint(x: f1x + 42, y: f1y + 40),
                control: CGPoint(x: f1x + 32, y: f1y + 34))
            context.stroke(arm1, with: .color(fig1Color), lineWidth: 6)
            context.fill(
                Path(ellipseIn: CGRect(x: f1x + 39, y: f1y + 37, width: 7, height: 7)),
                with: .color(fig1Color)
            )

            // -- Figure IA (droite) --
            let fig2Color = Color(red: 0.125, green: 0.125, blue: 0.28)
            let f2x: CGFloat = w * 0.54
            let f2y: CGFloat = h * 0.31

            // Aura subtile
            context.fill(
                Path(ellipseIn: CGRect(x: f2x - 14, y: f2y + 10, width: 60, height: 120)),
                with: .color(Color(red: 0.47, green: 0.67, blue: 1).opacity(0.04))
            )

            // Tête
            context.fill(
                Path(ellipseIn: CGRect(x: f2x + 2, y: f2y, width: 26, height: 26)),
                with: .color(fig2Color)
            )

            // Corps
            var body2 = Path()
            body2.move(to: CGPoint(x: f2x + 6, y: f2y + 24))
            body2.addQuadCurve(to: CGPoint(x: f2x + 4, y: f2y + 54), control: CGPoint(x: f2x + 3, y: f2y + 38))
            body2.addLine(to: CGPoint(x: f2x + 2, y: f2y + 110))
            body2.addLine(to: CGPoint(x: f2x + 12, y: f2y + 114))
            body2.addLine(to: CGPoint(x: f2x + 14, y: f2y + 78))
            body2.addQuadCurve(to: CGPoint(x: f2x + 18, y: f2y + 78), control: CGPoint(x: f2x + 16, y: f2y + 68))
            body2.addLine(to: CGPoint(x: f2x + 20, y: f2y + 114))
            body2.addLine(to: CGPoint(x: f2x + 30, y: f2y + 110))
            body2.addLine(to: CGPoint(x: f2x + 28, y: f2y + 54))
            body2.addQuadCurve(to: CGPoint(x: f2x + 24, y: f2y + 24), control: CGPoint(x: f2x + 27, y: f2y + 38))
            body2.closeSubpath()
            context.fill(body2, with: .color(fig2Color))

            // Bras tendu
            var arm2 = Path()
            arm2.move(to: CGPoint(x: f2x + 6, y: f2y + 36))
            arm2.addQuadCurve(
                to: CGPoint(x: f2x - 12, y: f2y + 44),
                control: CGPoint(x: f2x - 2, y: f2y + 38))
            context.stroke(arm2, with: .color(fig2Color), lineWidth: 6)
            context.fill(
                Path(ellipseIn: CGRect(x: f2x - 15, y: f2y + 41, width: 7, height: 7)),
                with: .color(fig2Color)
            )

            // -- Point de connexion (mains) --
            let connectPt = CGPoint(x: w * 0.5, y: h * 0.43)
            let connectRect = CGRect(
                x: connectPt.x - 4,
                y: connectPt.y - 4,
                width: 8, height: 8
            )
            context.fill(
                Path(ellipseIn: connectRect.insetBy(dx: -6, dy: -6)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1, green: 0.82, blue: 0.55).opacity(0.3),
                        Color.clear
                    ]),
                    center: connectPt,
                    startRadius: 0,
                    endRadius: 14
                )
            )
            context.fill(
                Path(ellipseIn: connectRect),
                with: .color(Color(red: 1, green: 0.94, blue: 0.78).opacity(0.4))
            )
        }
    }
}
