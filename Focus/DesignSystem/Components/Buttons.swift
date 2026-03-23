import SwiftUI

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    if let icon = icon {
                        // Check if it's a SF Symbol (no emoji characters) or emoji
                        if icon.unicodeScalars.allSatisfy({ $0.isASCII }) {
                            Image(systemName: icon)
                                .font(.satoshi(16, weight: .semibold))
                        } else {
                            Text(icon)
                        }
                    }
                    Text(title)
                        .subtitle()
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(ColorTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isDisabled
                    ? ColorTokens.disabledGradient
                    : ColorTokens.fireGradient
            )
            .cornerRadius(RadiusTokens.md)
            .shadow(
                color: isDisabled ? .clear : ColorTokens.primaryGlow,
                radius: 12,
                x: 0,
                y: 4
            )
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    
    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sm) {
                if let icon = icon {
                    Text(icon)
                }
                Text(title)
                    .bodyText()
                    .fontWeight(.medium)
            }
            .foregroundColor(isDisabled ? ColorTokens.textMuted : ColorTokens.primaryStart)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(
                        isDisabled ? ColorTokens.border : ColorTokens.primaryStart,
                        lineWidth: 1.5
                    )
            )
        }
        .disabled(isDisabled)
    }
}

// MARK: - Preview
#Preview("Buttons") {
    VStack(spacing: SpacingTokens.lg) {
        PrimaryButton("Start Focus Session", icon: "🔥") {}

        SecondaryButton("Log Manual Session") {}
    }
    .padding()
    .background(ColorTokens.background)
}
