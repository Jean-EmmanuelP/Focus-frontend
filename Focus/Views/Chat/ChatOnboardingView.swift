//
//  ChatOnboardingView.swift
//  Focus
//
//  Perplexity-style onboarding: Chat-first experience with deferred auth
//

import SwiftUI
import AuthenticationServices
import Combine

struct ChatOnboardingView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var viewModel = ChatOnboardingViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showLoginSheet = false

    // WhatsApp colors
    private let whatsAppHeaderGreen = Color(hex: "075E54")
    private let whatsAppSendGreen = Color(hex: "00A884")
    private let chatBackground = Color(hex: "ECE5DD")
    private let userBubbleColor = Color(hex: "DCF8C6")
    private let aiBubbleColor = Color.white
    private let inputBarBackground = Color(hex: "F0F0F0")

    var body: some View {
        ZStack {
            chatBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                chatHeader
                messagesView
                inputBar
            }
        }
        .onAppear {
            viewModel.loadInitialMessages()
        }
        .onTapGesture {
            isInputFocused = false
        }
        .sheet(isPresented: $showLoginSheet) {
            AppleSignInSheet(
                onSuccess: {
                    showLoginSheet = false
                    // After login, send the pending message
                    Task {
                        await viewModel.sendPendingMessage()
                    }
                },
                onCancel: {
                    showLoginSheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text("🔥")
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Kai")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Text(viewModel.isLoading ? "ecrit..." : "en ligne")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(whatsAppHeaderGreen)
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.messages) { message in
                        OnboardingBubble(
                            message: message,
                            userBubbleColor: userBubbleColor,
                            aiBubbleColor: aiBubbleColor
                        )
                        .id(message.id)
                    }

                    if viewModel.isLoading {
                        typingIndicator
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(18)
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Text field
            HStack {
                TextField("Message", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
            }
            .background(Color.white)
            .cornerRadius(24)

            // Send button
            Button {
                handleSendTap()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : whatsAppSendGreen)
                    .clipShape(Circle())
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(inputBarBackground)
    }

    // MARK: - Actions

    private func handleSendTap() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Store the pending message and show login
        viewModel.storePendingMessage(text)
        isInputFocused = false
        showLoginSheet = true
    }
}

// MARK: - Apple Sign In Sheet

struct AppleSignInSheet: View {
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @StateObject private var authService = AuthService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("🔥")
                    .font(.system(size: 48))

                Text("Connecte-toi pour continuer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Cree ton compte en un clic pour sauvegarder ta conversation et acceder a toutes les fonctionnalites")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 24)

            Spacer()

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // Apple Sign In Button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .disabled(isLoading)

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }

            // Cancel button
            Button {
                onCancel()
            } label: {
                Text("Plus tard")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                isLoading = true
                errorMessage = nil

                Task {
                    do {
                        try await authService.handleAppleCredential(appleIDCredential)
                        await MainActor.run {
                            isLoading = false
                            onSuccess()
                        }
                    } catch {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Connexion echouee. Reessaie."
            }
        }
    }
}

// MARK: - ViewModel for Onboarding Chat

@MainActor
class ChatOnboardingViewModel: ObservableObject {
    @Published var messages: [OnboardingChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false

    private var pendingMessage: String?

    func loadInitialMessages() {
        guard messages.isEmpty else { return }

        // Add initial Kai messages with slight delay for natural feel
        let message1 = OnboardingChatMessage(
            content: "Salut! Je suis Kai, ton coach de productivite personnel.",
            isFromUser: false
        )
        messages.append(message1)

        // Add second message after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            let message2 = OnboardingChatMessage(
                content: "Comment je peux t'aider aujourd'hui?",
                isFromUser: false
            )
            self?.messages.append(message2)
        }
    }

    func storePendingMessage(_ text: String) {
        pendingMessage = text
        // Show the message in the UI immediately
        let userMessage = OnboardingChatMessage(content: text, isFromUser: true)
        messages.append(userMessage)
        inputText = ""

        // Store for after login
        UserDefaults.standard.set(text, forKey: "pending_chat_message")
    }

    func sendPendingMessage() async {
        // After successful login, the main ChatView will pick up the pending message
        // We just need to ensure it's stored
        if let pending = pendingMessage {
            UserDefaults.standard.set(pending, forKey: "pending_chat_message")
        }
    }
}

// MARK: - Message Model

struct OnboardingChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp = Date()
}

// MARK: - Bubble View

struct OnboardingBubble: View {
    let message: OnboardingChatMessage
    let userBubbleColor: Color
    let aiBubbleColor: Color

    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 60) }

            HStack(alignment: .bottom, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundColor(.black)

                Text(formatTime(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(message.isFromUser ? userBubbleColor : aiBubbleColor)
            .cornerRadius(16)

            if !message.isFromUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ChatOnboardingView()
        .environmentObject(FocusAppStore.shared)
}
