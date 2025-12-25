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
                                .font(.inter(16, weight: .semibold))
                        } else {
                            Text(icon)
                        }
                    }
                    Text(title)
                        .subtitle()
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
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

// MARK: - Ghost Button
struct GhostButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)
        }
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 44
    var style: Style = .circular
    
    enum Style {
        case circular
        case square
    }
    
    var body: some View {
        Button(action: action) {
            Text(icon)
                .font(.inter(20))
                .frame(width: size, height: size)
                .background(ColorTokens.surface)
                .cornerRadius(style == .circular ? size / 2 : RadiusTokens.sm)
        }
    }
}

// MARK: - Chip Button (Tag selector)
struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .caption()
                .fontWeight(.medium)
                .foregroundColor(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.sm)
                .background(
                    isSelected
                        ? ColorTokens.primarySoft
                        : ColorTokens.surface
                )
                .cornerRadius(RadiusTokens.full)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.full)
                        .stroke(
                            isSelected ? ColorTokens.primaryStart : ColorTokens.border,
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - Duration Selector Button
struct DurationButton: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.xs) {
                Text("\(duration)")
                    .heading2()
                    .foregroundColor(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                Text("min")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                isSelected
                    ? ColorTokens.primarySoft
                    : ColorTokens.surface
            )
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(
                        isSelected ? ColorTokens.primaryStart : ColorTokens.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

// MARK: - Preview
#Preview("Buttons") {
    VStack(spacing: SpacingTokens.lg) {
        PrimaryButton("Start Focus Session", icon: "🔥") {}
        
        SecondaryButton("Log Manual Session") {}
        
        GhostButton("Cancel") {}
        
        HStack {
            IconButton(icon: "←") {}
            IconButton(icon: "✕") {}
        }
        
        HStack {
            ChipButton(title: "Health", isSelected: true) {}
            ChipButton(title: "Career", isSelected: false) {}
            ChipButton(title: "Learning", isSelected: false) {}
        }
        
        HStack(spacing: SpacingTokens.md) {
            DurationButton(duration: 25, isSelected: true) {}
            DurationButton(duration: 50, isSelected: false) {}
            DurationButton(duration: 90, isSelected: false) {}
        }
    }
    .padding()
    .background(ColorTokens.background)
}
