import SwiftUI

struct CategoryPickerSheet: View {
    let onSelect: (FocusRoomCategory) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 6) {
                Text("Choisis ta room")
                    .font(.satoshi(24, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Rejoins une session de groupe par categorie")
                    .font(.satoshi(14, weight: .medium))
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(.top, 24)

            // Category grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(FocusRoomCategory.allCases) { category in
                    CategoryCard(category: category) {
                        onSelect(category)
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(ColorTokens.background.ignoresSafeArea())
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: FocusRoomCategory
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.primaryGradient)

                Text(category.displayName)
                    .font(.satoshi(15, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(ColorTokens.border, lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
}

#Preview {
    CategoryPickerSheet { category in
        print("Selected: \(category.displayName)")
    }
}
