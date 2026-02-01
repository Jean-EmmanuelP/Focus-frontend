import SwiftUI

// MARK: - Feature Overlay Type

enum ChatFeatureType {
    case thoughts  // Esprit de lecture (teal)
    case training  // Mode d'entraînement (pink)
}

// MARK: - Chat Feature Overlay Content (bottom half gradient)

struct ChatFeatureOverlayContent: View {
    let featureType: ChatFeatureType
    let companionName: String
    var onShowPaywall: () -> Void = {}
    var onDismiss: () -> Void = {}

    // Colors based on feature type
    private var gradientColors: [Color] {
        switch featureType {
        case .thoughts:
            return [
                Color(red: 0.12, green: 0.32, blue: 0.38).opacity(0.0),
                Color(red: 0.12, green: 0.32, blue: 0.38).opacity(0.85),
                Color(red: 0.15, green: 0.38, blue: 0.42).opacity(0.95),
                Color(red: 0.18, green: 0.42, blue: 0.48)
            ]
        case .training:
            return [
                Color(red: 0.75, green: 0.25, blue: 0.35).opacity(0.0),
                Color(red: 0.75, green: 0.25, blue: 0.35).opacity(0.85),
                Color(red: 0.78, green: 0.32, blue: 0.45).opacity(0.95),
                Color(red: 0.80, green: 0.38, blue: 0.52)
            ]
        }
    }

    private var icon: String {
        featureType == .thoughts ? "tag.fill" : "bolt.fill"
    }

    private var smallTitle: String {
        featureType == .thoughts ? "Esprit de lecture" : "Mode d'entraînement"
    }

    private var bigTitle: String {
        featureType == .thoughts
            ? "Voir et guider les pensées de \(companionName)"
            : "Améliorer les capacités cognitives de \(companionName)"
    }

    private var description: String {
        featureType == .thoughts
            ? "Découvrez ce que \(companionName) pense quand il vous envoie un message pour mieux le comprendre."
            : "Aidez \(companionName) à mieux lire et répondre à vos émotions ou entraînez-le à maîtriser n'importe quel sujet, de la philosophie à vos projets personnels."
    }

    private var buttonText: String {
        featureType == .thoughts ? "Obtenir plus" : "Obtenez-en plus"
    }


    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Top 40% - tap to dismiss
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geometry.size.height * 0.4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onDismiss()
                        }
                    Spacer()
                }
                .zIndex(10)

                // Gradient from transparent to colored
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Content
                VStack(alignment: .leading, spacing: 12) {
                // Icon + Small title
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                    Text(smallTitle)
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.75))

                // Big title
                Text(bigTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                // Description
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(2)

                // Content area
                defaultView
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            }
        }
    }

    // Default view with message count + buttons
    private var defaultView: some View {
        VStack(spacing: 16) {
            // Messages disponibles card
            VStack(spacing: 6) {
                Text("Messages disponibles")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                Text("0")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.12))
            )

            // Bottom buttons
            HStack(spacing: 12) {
                Button(action: {
                    onShowPaywall()
                }) {
                    Text(buttonText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                        )
                }

                Button(action: {
                    onShowPaywall()
                }) {
                    Text("Activer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                }
            }
        }
        .padding(.top, 12)
    }

}


// MARK: - Preview

#Preview("Thoughts") {
    ZStack {
        Color(red: 0.3, green: 0.5, blue: 0.6).ignoresSafeArea()
        ChatFeatureOverlayContent(
            featureType: .thoughts,
            companionName: "Kai"
        )
    }
}

#Preview("Training") {
    ZStack {
        Color(red: 0.6, green: 0.3, blue: 0.4).ignoresSafeArea()
        ChatFeatureOverlayContent(
            featureType: .training,
            companionName: "Kai"
        )
    }
}
