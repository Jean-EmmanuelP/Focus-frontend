import SwiftUI

// MARK: - Custom Text Field
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?
    
    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            if let icon = icon {
                Text(icon)
                    .font(.satoshi(20))
            }
            
            TextField(placeholder, text: $text)
                .bodyText()
                .foregroundColor(ColorTokens.textPrimary)
                .accentColor(ColorTokens.primaryStart)
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }
}

// MARK: - Custom Text Area
struct CustomTextArea: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty && !isFocused {
                Text(placeholder)
                    .bodyText()
                    .foregroundColor(ColorTokens.textMuted)
                    .padding(SpacingTokens.md)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .bodyText()
                .foregroundColor(ColorTokens.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(SpacingTokens.sm)
                .focused($isFocused)
        }
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .stroke(isFocused ? ColorTokens.primaryStart : ColorTokens.border, lineWidth: isFocused ? 2 : 1)
        )
        .animation(.none, value: text) // Disable animations during typing
        .onTapGesture {
            isFocused = true
        }
    }
}

// MARK: - Checkbox
struct CheckboxView: View {
    let isChecked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isChecked ? ColorTokens.primaryStart : ColorTokens.border,
                        lineWidth: 2
                    )
                    .frame(width: 24, height: 24)
                
                if isChecked {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ColorTokens.primaryStart)
                        .frame(width: 24, height: 24)
                    
                    Text("✓")
                        .font(.satoshi(14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Rating View
struct RatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 10
    
    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(1...maxRating, id: \.self) { value in
                Button(action: {
                    rating = value
                }) {
                    Circle()
                        .fill(
                            value <= rating
                                ? ColorTokens.fireGradient
                                : ColorTokens.surfaceGradient
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(
                                    value <= rating ? Color.clear : ColorTokens.border,
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            Text("\(value)")
                                .caption()
                                .foregroundColor(
                                    value <= rating
                                        ? ColorTokens.textPrimary
                                        : ColorTokens.textMuted
                                )
                        )
                }
            }
        }
    }
}

// MARK: - Emoji Selector
struct EmojiSelector: View {
    let emojis: [Feeling]
    @Binding var selected: Feeling?
    
    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            ForEach(emojis, id: \.self) { feeling in
                Button(action: {
                    selected = feeling
                }) {
                    VStack(spacing: SpacingTokens.xs) {
                        Text(feeling.rawValue)
                            .font(.satoshi(32))
                        
                        Text(feeling.label)
                            .caption()
                            .foregroundColor(
                                selected == feeling
                                    ? ColorTokens.textPrimary
                                    : ColorTokens.textMuted
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.sm)
                    .background(
                        selected == feeling
                            ? ColorTokens.primarySoft
                            : ColorTokens.surface
                    )
                    .cornerRadius(RadiusTokens.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .stroke(
                                selected == feeling
                                    ? ColorTokens.primaryStart
                                    : ColorTokens.border,
                                lineWidth: selected == feeling ? 2 : 1
                            )
                    )
                }
            }
        }
    }
}

// MARK: - Dropdown Picker
struct DropdownPicker: View {
    let title: String
    let options: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        Menu {
            ForEach(0..<options.count, id: \.self) { index in
                Button(options[index]) {
                    selectedIndex = index
                }
            }
        } label: {
            HStack {
                Text(selectedIndex >= 0 ? options[selectedIndex] : title)
                    .bodyText()
                    .foregroundColor(
                        selectedIndex >= 0
                            ? ColorTokens.textPrimary
                            : ColorTokens.textMuted
                    )
                
                Spacer()
                
                Text("›")
                    .foregroundColor(ColorTokens.textMuted)
            }
            .padding(SpacingTokens.md)
            .background(ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(ColorTokens.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Slider with Value
struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 1
    var label: String
    
    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            HStack {
                Text(label)
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
                
                Spacer()
                
                Text("\(Int(value)) min")
                    .subtitle()
                    .foregroundColor(ColorTokens.textPrimary)
            }
            
            Slider(
                value: $value,
                in: range,
                step: step
            )
            .tint(ColorTokens.primaryStart)
            
            HStack {
                Text("\(Int(range.lowerBound))")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
                
                Spacer()
                
                Text("\(Int(range.upperBound))")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.md)
    }
}

// MARK: - Preview
#Preview("Inputs") {
    VStack(spacing: SpacingTokens.lg) {
        CustomTextField(
            placeholder: "Enter your intention...",
            text: .constant(""),
            icon: "✨"
        )
        
        CustomTextArea(
            placeholder: "Describe your focus area...",
            text: .constant("")
        )
        
        HStack {
            CheckboxView(isChecked: false) {}
            CheckboxView(isChecked: true) {}
        }
        
        RatingView(rating: .constant(7))
        
        EmojiSelector(
            emojis: [.happy, .calm, .neutral, .tired],
            selected: .constant(.calm)
        )
        
        DropdownPicker(
            title: "Select area",
            options: ["Health", "Career", "Learning"],
            selectedIndex: .constant(0)
        )
        
        CustomSlider(
            value: .constant(25),
            range: 5...180,
            step: 5,
            label: "Duration"
        )
    }
    .padding()
    .background(ColorTokens.background)
}
