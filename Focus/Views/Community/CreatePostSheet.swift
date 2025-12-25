import SwiftUI
import PhotosUI

struct CreatePostSheet: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.lg) {
                        // Photo Picker
                        photoPickerSection

                        // Caption
                        captionSection

                        // Link to Task/Routine
                        linkSection

                        Spacer(minLength: SpacingTokens.xxl)
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.top, SpacingTokens.md)
                }
            }
            .navigationTitle("community.create_post".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        viewModel.resetCreatePostForm()
                        dismiss()
                    }
                    .foregroundColor(ColorTokens.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("community.post".localized) {
                        Task {
                            let success = await viewModel.createPost()
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .disabled(!canPost)
                    .opacity(canPost ? 1 : 0.5)
                }
            }
            .overlay {
                if viewModel.isCreatingPost {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: SpacingTokens.md) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("community.posting".localized)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(SpacingTokens.xl)
                        .background(.ultraThinMaterial)
                        .cornerRadius(RadiusTokens.lg)
                    }
                }
            }
            .task {
                await viewModel.loadCreatePostOptions()
            }
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    viewModel.selectedImage = image
                    showCamera = false
                }
            }
        }
    }

    private var canPost: Bool {
        viewModel.selectedImage != nil && !viewModel.isCreatingPost
    }

    // MARK: - Photo Picker Section
    private var photoPickerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("community.photo".localized)
                .font(.headline)
                .foregroundColor(ColorTokens.textPrimary)

            if let image = viewModel.selectedImage {
                // Selected image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipped()
                    .cornerRadius(RadiusTokens.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.lg)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        Button {
                            viewModel.selectedImage = nil
                            viewModel.selectedPhotoItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .black.opacity(0.5))
                                .padding(SpacingTokens.sm)
                        }
                    }
            } else {
                // Photo selection options - Camera first (BeReal style)
                HStack(spacing: SpacingTokens.md) {
                    // Camera button (primary)
                    Button {
                        showCamera = true
                    } label: {
                        VStack(spacing: SpacingTokens.sm) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [ColorTokens.primaryStart, ColorTokens.primaryEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("community.take_selfie".localized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(ColorTokens.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                                .stroke(ColorTokens.primaryStart.opacity(0.5), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    // Gallery picker (secondary)
                    PhotosPicker(
                        selection: $viewModel.selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        VStack(spacing: SpacingTokens.sm) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 32))
                                .foregroundColor(ColorTokens.textSecondary)

                            Text("community.from_gallery".localized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(ColorTokens.surface)
                        .cornerRadius(RadiusTokens.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                                .stroke(ColorTokens.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.selectedImage = image
                }
            }
        }
    }

    // MARK: - Caption Section
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("community.caption".localized)
                .font(.headline)
                .foregroundColor(ColorTokens.textPrimary)

            TextField("community.caption_placeholder".localized, text: $viewModel.caption, axis: .vertical)
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
    }

    // MARK: - Link Section
    private var linkSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("community.link_to".localized)
                .font(.headline)
                .foregroundColor(ColorTokens.textPrimary)

            Text("community.link_description".localized)
                .font(.caption)
                .foregroundColor(ColorTokens.textSecondary)

            if viewModel.isLoadingOptions {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, SpacingTokens.lg)
            } else {
                // Tasks
                if !viewModel.availableTasks.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("community.tasks".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textSecondary)
                            .padding(.top, SpacingTokens.sm)

                        ForEach(viewModel.availableTasks) { task in
                            linkableItemRow(
                                icon: "checkmark.circle",
                                title: task.title,
                                isSelected: viewModel.selectedTaskId == task.id,
                                color: ColorTokens.primaryStart,
                                isSystemIcon: true
                            ) {
                                viewModel.selectedTaskId = task.id
                                viewModel.selectedRoutineId = nil
                            }
                        }
                    }
                }

                // Routines
                if !viewModel.availableRoutines.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("community.rituals".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ColorTokens.textSecondary)
                            .padding(.top, SpacingTokens.sm)

                        ForEach(viewModel.availableRoutines, id: \.id) { routine in
                            linkableItemRow(
                                icon: routine.icon ?? "arrow.triangle.2.circlepath",
                                title: routine.title,
                                isSelected: viewModel.selectedRoutineId == routine.id,
                                color: ColorTokens.warning,
                                isSystemIcon: routine.icon == nil
                            ) {
                                viewModel.selectedRoutineId = routine.id
                                viewModel.selectedTaskId = nil
                            }
                        }
                    }
                }

                if viewModel.availableTasks.isEmpty && viewModel.availableRoutines.isEmpty {
                    VStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(ColorTokens.textMuted)

                        Text("community.no_items_to_link".localized)
                            .font(.subheadline)
                            .foregroundColor(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.xl)
                }
            }
        }
    }

    private func linkableItemRow(icon: String, title: String, isSelected: Bool, color: Color, isSystemIcon: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.md) {
                // Handle SF Symbol vs emoji
                if isSystemIcon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                } else {
                    Text(icon)
                        .font(.title3)
                }

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(ColorTokens.textPrimary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                }
            }
            .padding(SpacingTokens.md)
            .background(isSelected ? color.opacity(0.1) : ColorTokens.surface)
            .cornerRadius(RadiusTokens.md)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .stroke(isSelected ? color : ColorTokens.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    CreatePostSheet(viewModel: CommunityViewModel())
}
