import SwiftUI

struct ReportPostSheet: View {
    let post: CommunityPostResponse
    let onSubmit: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: ReportReason?
    @State private var details: String = ""
    @State private var isSubmitting = false

    enum ReportReason: String, CaseIterable, Identifiable {
        case inappropriate = "inappropriate"
        case spam = "spam"
        case harassment = "harassment"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .inappropriate: return "community.report_inappropriate".localized
            case .spam: return "community.report_spam".localized
            case .harassment: return "community.report_harassment".localized
            case .other: return "community.report_other".localized
            }
        }

        var icon: String {
            switch self {
            case .inappropriate: return "eye.slash"
            case .spam: return "envelope.badge"
            case .harassment: return "exclamationmark.bubble"
            case .other: return "questionmark.circle"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                        // Header
                        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                            Text("community.report_title".localized)
                                .font(.headline)
                                .foregroundColor(ColorTokens.textPrimary)

                            Text("community.report_subtitle".localized)
                                .font(.subheadline)
                                .foregroundColor(ColorTokens.textSecondary)
                        }

                        // Reason selection
                        VStack(spacing: SpacingTokens.sm) {
                            ForEach(ReportReason.allCases) { reason in
                                reasonButton(reason)
                            }
                        }

                        // Additional details
                        if selectedReason != nil {
                            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                                Text("community.report_details".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(ColorTokens.textPrimary)

                                TextField("community.report_details_placeholder".localized, text: $details, axis: .vertical)
                                    .lineLimit(3...6)
                                    .textFieldStyle(.plain)
                                    .padding(SpacingTokens.md)
                                    .background(ColorTokens.surface)
                                    .cornerRadius(RadiusTokens.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                                            .stroke(ColorTokens.border, lineWidth: 1)
                                    )
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Submit button
                        Button(action: submitReport) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("community.report_submit".localized)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SpacingTokens.md)
                            .foregroundColor(.white)
                            .background(
                                selectedReason != nil
                                    ? Color.red
                                    : Color.gray
                            )
                            .cornerRadius(RadiusTokens.md)
                        }
                        .disabled(selectedReason == nil || isSubmitting)
                        .padding(.top, SpacingTokens.md)

                        Spacer(minLength: SpacingTokens.xl)
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.top, SpacingTokens.md)
                }
            }
            .navigationTitle("community.report".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedReason)
        }
    }

    private func reasonButton(_ reason: ReportReason) -> some View {
        Button {
            selectedReason = reason
        } label: {
            HStack(spacing: SpacingTokens.md) {
                Image(systemName: reason.icon)
                    .font(.title3)
                    .foregroundColor(selectedReason == reason ? .red : ColorTokens.textSecondary)
                    .frame(width: 24)

                Text(reason.title)
                    .font(.subheadline)
                    .foregroundColor(ColorTokens.textPrimary)

                Spacer()

                if selectedReason == reason {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(SpacingTokens.md)
            .background(selectedReason == reason ? Color.red.opacity(0.1) : ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(selectedReason == reason ? Color.red : ColorTokens.border, lineWidth: selectedReason == reason ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func submitReport() {
        guard let reason = selectedReason else { return }

        isSubmitting = true
        onSubmit(reason.rawValue, details.isEmpty ? nil : details)

        // Dismiss after a short delay to show feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    ReportPostSheet(
        post: CommunityPostResponse(
            id: "1",
            userId: "user1",
            taskId: "task1",
            routineId: nil,
            imageUrl: "https://picsum.photos/400/400",
            caption: "Test post",
            likesCount: 42,
            createdAt: Date(),
            user: PostUser(id: "user1", pseudo: "JohnDoe", avatarUrl: nil),
            taskTitle: "Morning Workout",
            routineTitle: nil,
            isLikedByMe: false
        ),
        onSubmit: { _, _ in }
    )
}
