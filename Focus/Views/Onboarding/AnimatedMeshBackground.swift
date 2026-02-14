//
//  AnimatedMeshBackground.swift
//  Focus
//
//  Replika-style animated blue background
//  Light shapes orbit around screen edges and occasionally sweep through
//

import SwiftUI

struct AnimatedMeshBackground: View {
    @State private var x1 = false
    @State private var y1 = false
    @State private var x2 = false
    @State private var y2 = false
    @State private var x3 = false
    @State private var y3 = false
    @State private var r1 = false
    @State private var r2 = false
    @State private var r3 = false

    var body: some View {
        // Color as base ensures stable layout - blobs in overlay don't affect sizing
        Color(red: 0.10, green: 0.33, blue: 0.92)
            .overlay(
                ZStack {
                    // Blob 1 - Orbits top-right to bottom-left
                    RoundedRectangle(cornerRadius: 150)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.40),
                                    Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.12),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 220
                            )
                        )
                        .frame(width: 450, height: 300)
                        .rotationEffect(.degrees(r1 ? 25 : -25))
                        .offset(
                            x: x1 ? 180 : -180,
                            y: y1 ? -350 : 200
                        )
                        .blur(radius: 55)

                    // Blob 2 - Counter-orbits left to right
                    RoundedRectangle(cornerRadius: 120)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.60),
                                    Color.white.opacity(0.28),
                                    Color(red: 0.50, green: 0.70, blue: 1.0).opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 200
                            )
                        )
                        .frame(width: 280, height: 450)
                        .rotationEffect(.degrees(r2 ? -30 : 20))
                        .offset(
                            x: x2 ? -200 : 200,
                            y: y2 ? 300 : -300
                        )
                        .blur(radius: 50)

                    // Blob 3 - Sweeps bottom to top
                    RoundedRectangle(cornerRadius: 100)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.18),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 15,
                                endRadius: 180
                            )
                        )
                        .frame(width: 400, height: 250)
                        .rotationEffect(.degrees(r3 ? 15 : -20))
                        .offset(
                            x: x3 ? 150 : -120,
                            y: y3 ? -280 : 350
                        )
                        .blur(radius: 50)
                }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                    x1 = true
                }
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    y1 = true
                }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    r1 = true
                }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    x2 = true
                }
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    y2 = true
                }
                withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                    r2 = true
                }
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    x3 = true
                }
                withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                    y3 = true
                }
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                    r3 = true
                }
            }
    }
}

#Preview {
    AnimatedMeshBackground()
}
