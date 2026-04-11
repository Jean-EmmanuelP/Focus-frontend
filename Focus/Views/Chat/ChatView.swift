import SwiftUI
import AVFoundation
import Combine
import WebKit

// MARK: - Replika-Style Chat View

struct ChatView: View {
    @EnvironmentObject var store: FocusAppStore
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showSettings = false

    // Recording state
    @StateObject private var audioRecorder = VoiceRecorderManager()
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var showPaywall = false
    @State private var showCompanionProfile = false
    @State private var showStatsProfile = false
    @State private var showVoiceCall = false
    @State private var isHomeMode = false  // Toggle between home view and chat view
    @State private var showAppBlocker = false
    @State private var isAvatarPaused = false
    @State private var showDiscoverMap = false
    @State private var showActionButtons = false
    @State private var showPlanning = false
    @State private var showMorningVerification = false
    @State private var showCopiedToast = false

    @EnvironmentObject var subscriptionManager: SubscriptionManager

    // Companion name (from user settings)
    private var companionName: String {
        store.user?.companionName ?? "ton coach"
    }

    private var userInitialForChat: String {
        if let first = store.user?.firstName, !first.isEmpty {
            return String(first.prefix(1)).uppercased()
        }
        return String(store.user?.name.prefix(1) ?? "U").uppercased()
    }

    private var companionInitialForChat: String {
        String(companionName.prefix(1)).uppercased()
    }

    private var dynamicPlaceholder: String {
        if viewModel.messages.isEmpty {
            return "Demande à \(companionName) de planifier ta journée"
        }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 20 {
            return "Comment s'est passée ta journée ?"
        }
        return "Message..."
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blue gradient background (like Replika)
                replikaBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header - changes based on mode
                    if isHomeMode {
                        homeHeader
                    } else {
                        conversationHeader
                    }

                    // App blocking banner
                    if ScreenTimeAppBlockerService.shared.isBlocking {
                        AppBlockingBanner()
                            .padding(.top, 6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Content area — tap to dismiss action buttons
                    if isHomeMode {
                        // Home mode: just spacer, avatar is background
                        Spacer()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if showActionButtons {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        showActionButtons = false
                                    }
                                }
                            }
                    } else {
                        // Chat mode: messages overlay on avatar background
                        messagesScrollView
                            .onTapGesture {
                                if showActionButtons {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        showActionButtons = false
                                    }
                                }
                            }
                    }

                    // Input bar - always visible
                    replikaInputBar
                }

            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setStore(store)
            viewModel.loadHistory()
        }
        .onDisappear {
            // Clean up timer to prevent memory leak
            recordingTimer?.invalidate()
            recordingTimer = nil
        }
        .onTapGesture {
            // Only dismiss keyboard from background areas, not during active chat
            if isHomeMode || viewModel.messages.isEmpty {
                isInputFocused = false
            }
        }
        .overlay {
            if showPaywall {
                FocusPaywallView(
                    companionName: companionName,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPaywall = false
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPaywall = false
                        }
                    }
                )
                .environmentObject(subscriptionManager)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPaywall)
        .onChange(of: showPaywall) { _, isShowing in
            if isShowing {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onChange(of: showSettings) { _, isShowing in
            if isShowing {
                isInputFocused = false
            }
        }
        .overlay {
            if showCompanionProfile {
                CompanionProfileView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCompanionProfile = false
                    }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCompanionProfile)
        .animation(.easeInOut(duration: 0.3), value: isHomeMode)
        .overlay {
            if showSettings {
                SettingsPageView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSettings = false
                    }
                })
                .environmentObject(store)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSettings)
        .fullScreenCover(isPresented: $showStatsProfile) {
            StatsProfileView()
                .environmentObject(store)
        }
        .overlay {
            if showAppBlocker {
                AppBlockerSettingsView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) { showAppBlocker = false }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showAppBlocker)
        .overlay {
            if showDiscoverMap {
                DiscoverMapView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) { showDiscoverMap = false }
                })
                .environmentObject(subscriptionManager)
                .environmentObject(store)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showDiscoverMap)
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Copié")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showCopiedToast)
        .onChange(of: showAppBlocker) { _, isShowing in
            // Auto-start blocking when user closes the app blocker settings after selecting apps
            if !isShowing {
                let blocker = ScreenTimeAppBlockerService.shared
                if blocker.hasSelectedApps && !blocker.isBlocking {
                    blocker.startBlocking()
                    let confirmMsg = SimpleChatMessage(content: "Apps bloquées ! Tu peux te concentrer maintenant.", isFromUser: false)
                    viewModel.messages.append(confirmMsg)
                    viewModel.saveMessages()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAppBlockerSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showAppBlocker = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .forceUnblockApps)) { _ in
            let blocker = ScreenTimeAppBlockerService.shared
            blocker.stopBlocking()
            let confirmMsg = SimpleChatMessage(content: "Apps débloquées !", isFromUser: false)
            viewModel.messages.append(confirmMsg)
            viewModel.saveMessages()
        }
        .fullScreenCover(isPresented: $showVoiceCall) {
            VoiceCallView()
        }
        .fullScreenCover(isPresented: $showMorningVerification) {
            VoiceCallView(mode: "morning_verification")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMorningVerification)) { _ in
            showMorningVerification = true
        }
        .fullScreenCover(isPresented: $showPlanning) {
            PlanningView()
                .environmentObject(store)
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused {
                // Pause 3D scene immediately to free GPU for keyboard animation
                isAvatarPaused = true
                // Exit home mode when user starts typing (only if there are messages)
                if isHomeMode && !viewModel.messages.isEmpty {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isHomeMode = false
                    }
                }
            } else {
                // Resume 3D scene after keyboard dismiss animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isAvatarPaused = false
                }
            }
        }
    }

    // MARK: - Background (Focus Pulse)

    private var replikaBackground: some View {
        FocusPulseView()
            .ignoresSafeArea()
    }

    // MARK: - Home Header (home mode or empty state)

    private var homeHeader: some View {
        HStack {
            // Left: Profile photo
            Button(action: {
                isInputFocused = false
                showStatsProfile = true
            }) {
                if let avatarURL = store.user?.avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            profilePlaceholder
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    )
                } else {
                    profilePlaceholder
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
            }

            Spacer()

            // Center: Companion name (opens stats)
            Button(action: {
                isInputFocused = false
                showStatsProfile = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text(companionName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text("\(store.currentStreak)j")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.orange.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
            }

            Spacer()

            // Right: Settings gear
            Button(action: {
                isInputFocused = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings = true
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
            Text(String(store.user?.name.prefix(1) ?? "U").uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Conversation Header

    private var conversationHeader: some View {
        HStack(spacing: 12) {
            // Left: Home button + companion name
            HStack(spacing: 8) {
                Button(action: {
                    isInputFocused = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isHomeMode = true
                    }
                }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )
                }

                Button(action: {
                    isInputFocused = false
                    showStatsProfile = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text(companionName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("·")
                            .foregroundColor(.white.opacity(0.3))
                        Text("\(store.currentStreak)j")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
            }

            Spacer()

            // Right: Map + Settings
            HStack(spacing: 8) {
                if AppConfiguration.FeatureFlags.discoverMapEnabled {
                    Button(action: {
                        isInputFocused = false
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showDiscoverMap = true
                        }
                    }) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                }

                Button(action: {
                    isInputFocused = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSettings = true
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }


    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    if viewModel.messages.isEmpty {
                        // Welcome state
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)

                            Text("Salut ! Je suis \(companionName)")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.95))
                                .cornerRadius(26)

                            Text("Écris-moi pour commencer")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                    } else {
                        // Group messages by date
                        ForEach(viewModel.groupedMessages) { group in
                            // Date separator
                            dateSeparator(date: group.date)

                            // Messages for this date
                            ForEach(group.messages) { message in
                                ReplikaMessageBubble(
                                    message: message.withResolvedContent(viewModel.resolvedContent),
                                    viewModel: viewModel,
                                    userAvatarURL: store.user?.avatarURL,
                                    userInitial: userInitialForChat,
                                    companionInitial: companionInitialForChat,
                                    showCopiedToast: $showCopiedToast
                                )
                                .id(message.id)
                            }
                        }
                    }

                    if viewModel.isLoading {
                        typingIndicator
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    // Wait for keyboard animation to finish, then scroll
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private static let dateSeparatorFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    private func dateSeparator(date: Date) -> some View {
        return Text(Self.dateSeparatorFormatter.string(from: date))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
            )
            .padding(.vertical, 8)
    }

    private var typingIndicator: some View {
        HStack {
            TypingDotsView()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.95))
                .cornerRadius(20)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Input Bar (Replika style)

    private var replikaInputBar: some View {
        Group {
            if isRecording {
                // WhatsApp-style recording bar
                recordingInputBar
            } else {
                // Normal input bar
                normalInputBar
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.25), value: isRecording)
    }

    // MARK: - Normal Input Bar

    private var normalInputBar: some View {
        HStack(spacing: 8) {
            // Left: Expandable action buttons
            ZStack(alignment: .bottom) {
                // Planning button (deploys highest)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showActionButtons = false
                    }
                    showPlanning = true
                }) {
                    Image(systemName: "checklist")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .offset(y: showActionButtons ? -116 : 0)
                .opacity(showActionButtons ? 1 : 0)
                .scaleEffect(showActionButtons ? 1 : 0.4)
                .allowsHitTesting(showActionButtons)

                // Phone call button (deploys upward)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showActionButtons = false
                    }
                    #if DEBUG
                    showVoiceCall = true
                    #else
                    if subscriptionManager.isProUser {
                        showVoiceCall = true
                    } else {
                        showPaywall = true
                    }
                    #endif
                }) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .offset(y: showActionButtons ? -60 : 0)
                .opacity(showActionButtons ? 1 : 0)
                .scaleEffect(showActionButtons ? 1 : 0.4)
                .allowsHitTesting(showActionButtons)

                // Main toggle button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showActionButtons.toggle()
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .rotationEffect(.degrees(showActionButtons ? 45 : 0))
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
            }

            // Text field capsule
            HStack(spacing: 0) {
                TextField("", text: $viewModel.inputText, prompt: Text(dynamicPlaceholder).foregroundColor(.white.opacity(0.45)))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .focused($isInputFocused)

                Spacer()

                if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isHomeMode = false
                        }
                        viewModel.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                } else {
                    Button {
                        if viewModel.canSendFreeVoice {
                            startRecording()
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color(red: 0.25, green: 0.28, blue: 0.35).opacity(0.85))
            )
            .contentShape(Capsule())
        }
    }

    // MARK: - Recording Bar (Apple style)

    private var recordingInputBar: some View {
        HStack(spacing: 12) {
            // Cancel
            Button {
                cancelRecording()
            } label: {
                Text("Annuler")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Timer + waveform
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(recordingDotOpacity)

                Text(formatRecordingTime(recordingTime))
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))

                // Waveform bars
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 2, height: 4)
                            .scaleEffect(y: waveformScale(for: i), anchor: .center)
                    }
                }
            }

            Spacer()

            // Send button (blue circle, arrow up — like iMessage)
            Button {
                stopRecordingAndSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(red: 0.20, green: 0.45, blue: 1.0))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(red: 0.25, green: 0.28, blue: 0.35).opacity(0.85))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Recording Helpers

    @State private var recordingDotOpacity: Double = 1.0

    private func waveformScale(for index: Int) -> CGFloat {
        // Animated dots that pulse based on time — creates a traveling wave effect
        let phase = recordingTime * 4.0 + Double(index) * 0.3
        let wave = sin(phase) * 0.5 + 0.5
        return CGFloat(1.0 + wave * 3.5)
    }

    private func formatRecordingTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDotOpacity = 1.0
        isRecording = false
        _ = audioRecorder.stopRecording()
        HapticFeedback.heavy()
    }

    // MARK: - Recording Functions

    private func startRecording() {
        HapticFeedback.medium()
        audioRecorder.startRecording()
        isRecording = true
        recordingTime = 0

        // Blink the recording dot
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            recordingDotOpacity = 0.2
        }

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }

    private func stopRecordingAndSend() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDotOpacity = 1.0

        guard isRecording else { return }
        isRecording = false
        HapticFeedback.light()

        if let audioURL = audioRecorder.stopRecording(), recordingTime > 0.5 {
            Task {
                await viewModel.sendVoiceMessage(audioURL: audioURL)
            }
        }
    }
}

// MARK: - Satisfaction Gauge View (kept for potential reuse)

struct SatisfactionGaugeView: View {
    let score: Int
    var size: CGFloat = 60

    private var progress: Double {
        Double(max(0, min(100, score))) / 100.0
    }

    private var gaugeColor: Color {
        switch score {
        case ..<30: return Color(red: 0.9, green: 0.25, blue: 0.2)
        case 30..<50: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case 50..<70: return Color(red: 0.95, green: 0.8, blue: 0.2)
        case 70..<86: return Color(red: 0.45, green: 0.85, blue: 0.4)
        default: return Color(red: 0.2, green: 0.85, blue: 0.35)
        }
    }

    private var emoji: String {
        switch score {
        case ..<20: return "😴"
        case 20..<40: return "😐"
        case 40..<60: return "💪"
        case 60..<80: return "⚡"
        default: return "🔥"
        }
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: size * 0.08)

            // Colored arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(gaugeColor, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: score)

            // Emoji + score
            VStack(spacing: 0) {
                if size >= 50 {
                    Text(emoji)
                        .font(.system(size: size * 0.2))
                    Text("\(score)")
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Text("\(score)")
                        .font(.system(size: size * 0.33, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Score Detail Popup

struct ScoreDetailSheet: View {
    @EnvironmentObject var store: FocusAppStore
    let score: Int

    private var tasksCompleted: Int { store.todaysTasks.filter { $0.isCompleted }.count }
    private var tasksTotal: Int { store.todaysTasks.count }
    private var ritualsCompleted: Int { store.rituals.filter { $0.isCompleted }.count }
    private var ritualsTotal: Int { store.rituals.count }
    private var focusMinutes: Int { store.todayMinutes }
    private var streak: Int { store.currentStreak }

    // Percentages for each category (matches ChatViewModel formula)
    private var tasksPct: Double {
        guard tasksTotal > 0 else { return 0 }
        return Double(tasksCompleted) / Double(tasksTotal)
    }
    private var ritualsPct: Double {
        guard ritualsTotal > 0 else { return 0 }
        return Double(ritualsCompleted) / Double(ritualsTotal)
    }
    private var focusPct: Double {
        min(1.0, Double(focusMinutes) / 25.0)
    }

    private var tasksRemaining: Int { tasksTotal - tasksCompleted }
    private var ritualsRemaining: Int { ritualsTotal - ritualsCompleted }
    private var focusRemaining: Int { max(0, 25 - focusMinutes) }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Header: score + message
            VStack(spacing: 8) {
                Text("\(score)%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(scoreMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 16)

            // "Pour atteindre 100%"
            if score < 100 {
                Text("Pour atteindre 100%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
            }

            // Categories
            VStack(spacing: 8) {
                progressRow(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    label: "Tâches",
                    progress: tasksPct,
                    status: tasksTotal == 0 ? "Crée des tâches" : "\(tasksCompleted)/\(tasksTotal)",
                    done: tasksTotal > 0 && tasksCompleted == tasksTotal,
                    action: tasksTotal == 0 ? "Demande à ton coach de planifier ta journée" : tasksRemaining > 0 ? "Termine \(tasksRemaining) tâche\(tasksRemaining > 1 ? "s" : "")" : nil
                )

                progressRow(
                    icon: "sparkles",
                    color: .teal,
                    label: "Rituels",
                    progress: ritualsPct,
                    status: ritualsTotal == 0 ? "Crée des rituels" : "\(ritualsCompleted)/\(ritualsTotal)",
                    done: ritualsTotal > 0 && ritualsCompleted == ritualsTotal,
                    action: ritualsTotal == 0 ? "Crée tes rituels quotidiens" : ritualsRemaining > 0 ? "Complète \(ritualsRemaining) rituel\(ritualsRemaining > 1 ? "s" : "")" : nil
                )

                progressRow(
                    icon: "timer",
                    color: .orange,
                    label: "Focus",
                    progress: focusPct,
                    status: "\(focusMinutes)/25 min",
                    done: focusMinutes >= 25,
                    action: focusRemaining > 0 ? "\(focusRemaining) min de concentration" : nil
                )
            }
            .padding(.horizontal, 16)

            // Streak badge (separate — not part of %)
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Streak")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(streak > 0 ? "\(streak) jour\(streak > 1 ? "s" : "") d'affilée" : "Atteins 100% pour démarrer")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Text("\(streak)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(streak > 0 ? .orange : .white.opacity(0.3))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.orange.opacity(streak > 0 ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(streak > 0 ? 0.15 : 0), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()
        }
        .background(Color(red: 0.10, green: 0.12, blue: 0.20).ignoresSafeArea())
    }

    private func progressRow(icon: String, color: Color, label: String, progress: Double, status: String, done: Bool, action: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(done ? .green : color)
                    .frame(width: 26, height: 26)
                    .background((done ? Color.green : color).opacity(0.15))
                    .cornerRadius(7)

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text(status)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(done ? .green : .white.opacity(0.6))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(done ? Color.green : color)
                        .frame(width: max(0, geo.size.width * progress))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 5)

            // Action hint
            if let action = action {
                Text("→ \(action)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color.opacity(0.8))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(done ? 0.06 : 0.03))
        )
    }

    private var scoreMessage: String {
        switch score {
        case 0: return "Commence ta journée !"
        case 1..<30: return "C'est parti, continue !"
        case 30..<60: return "Tu avances bien"
        case 60..<90: return "Belle journée en cours"
        case 90..<100: return "Presque parfait !"
        default: return "Journée parfaite !"
        }
    }
}

// MARK: - Chat Avatar

struct ChatAvatar: View {
    let url: String?
    let initial: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initialView
                    }
                }
            } else {
                initialView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialView: some View {
        ZStack {
            Circle().fill(color)
            Text(initial)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Replika Message Bubble

struct ReplikaMessageBubble: View {
    let message: SimpleChatMessage
    var viewModel: ChatViewModel?
    var userAvatarURL: String? = nil
    var userInitial: String = ""
    var companionInitial: String = ""
    @Binding var showCopiedToast: Bool

    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var isDownloading = false
    @State private var downloadedLocalURL: URL?

    // Colors
    private let userBubbleColor = Color(red: 0.22, green: 0.28, blue: 0.42) // Dark navy blue
    private let aiBubbleColor = Color.white.opacity(0.95) // White/cream

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                if message.isFromUser {
                    Spacer(minLength: 80)
                } else {
                    // Coach avatar
                    ChatAvatar(
                        url: nil,
                        initial: companionInitial,
                        color: Color(red: 0.25, green: 0.50, blue: 1.0)
                    )
                }

                VStack(alignment: .trailing, spacing: 4) {
                    if message.type == .voice {
                        voiceMessageBubble
                    } else {
                        textBubble
                    }

                    // Failed status: retry button
                    if message.isFromUser && message.status == .failed {
                        Button {
                            viewModel?.retryMessage(message)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Réessayer")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }

                if message.isFromUser {
                    // User avatar
                    ChatAvatar(
                        url: userAvatarURL,
                        initial: userInitial,
                        color: Color(red: 0.22, green: 0.28, blue: 0.42)
                    )
                } else {
                    Spacer().frame(width: 4)
                }
            }

            // Card data (task list, routine list)
            if let cardData = message.cardData {
                HStack {
                    Spacer().frame(width: 34) // align with avatar
                    cardView(for: cardData)
                    Spacer().frame(width: 16)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var markdownContent: AttributedString {
        (try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(message.content)
    }

    private var textBubble: some View {
        Text(markdownContent)
            .font(.system(size: 16))
            .foregroundColor(message.isFromUser ? .white : .black)
            .textSelection(.enabled)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(message.isFromUser ? userBubbleColor : aiBubbleColor)
            .cornerRadius(26)
            .opacity(message.status == .sending ? 0.6 : 1.0)
            .opacity(message.status == .failed ? 0.5 : 1.0)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedToast = false
                    }
                } label: {
                    Label("Copier le message", systemImage: "doc.on.doc")
                }
            } preview: {
                Text(markdownContent)
                    .font(.system(size: 16))
                    .foregroundColor(message.isFromUser ? .white : .black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(message.isFromUser ? userBubbleColor : aiBubbleColor)
                    .cornerRadius(26)
                    .padding(8)
            }
    }

    // MARK: - Card Views

    @ViewBuilder
    private func cardView(for cardData: ChatCardData) -> some View {
        switch cardData {
        case .taskList(let tasks):
            InlineTaskListCard(tasks: tasks, messageId: message.id, viewModel: viewModel)
        case .routineList(let routines):
            InlineRoutineListCard(routines: routines, messageId: message.id, viewModel: viewModel)
        case .planning(let tasks, let routines, let focusState):
            InlinePlanningCard(tasks: tasks, routines: routines, focusState: focusState, messageId: message.id, viewModel: viewModel)
        case .videoCard(let video):
            InlineVideoCard(video: video, messageId: message.id, viewModel: viewModel)
        case .videoSuggestions(let data):
            VideoSuggestionsCard(data: data, messageId: message.id, viewModel: viewModel)
        case .actionButton(let action):
            Button {
                NotificationCenter.default.post(name: Notification.Name(action.deepLink), object: nil)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: action.icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(action.title)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
        case .productivityDiagnostic(let data):
            ProductivityDiagnosticCard(data: data, viewModel: viewModel)
        }
    }

    // Voice message
    private var audioAvailable: Bool {
        message.hasLocalAudio || message.voiceStoragePath != nil || downloadedLocalURL != nil
    }

    private var playableURL: URL? {
        if let downloaded = downloadedLocalURL {
            return downloaded
        }
        return message.localVoiceURL
    }

    private var voiceMessageBubble: some View {
        let isUser = message.isFromUser
        let textColor: Color = isUser ? .white : .black
        let bgColor = isUser ? userBubbleColor : aiBubbleColor

        return HStack(spacing: 12) {
            Button {
                if audioPlayer.isPlaying {
                    audioPlayer.pause()
                } else if let url = playableURL, FileManager.default.fileExists(atPath: url.path) {
                    audioPlayer.play(url: url)
                } else if message.voiceStoragePath != nil {
                    downloadAndPlay()
                }
            } label: {
                if isDownloading {
                    ProgressView()
                        .tint(textColor)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                        .frame(width: 32, height: 32)
                }
            }

            // Waveform
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    let progress = audioPlayer.isPlaying ? audioPlayer.progress : 0
                    let isPlayed = Double(i) / 20.0 < progress
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPlayed ? textColor : textColor.opacity(0.3))
                        .frame(width: 3, height: waveformHeight(for: i))
                }
            }
            .frame(height: 20)

            Text(formatDuration(message.voiceDuration ?? 0))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(bgColor)
        .cornerRadius(26)
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [6, 12, 8, 16, 10, 18, 6, 14, 12, 8, 16, 6, 12, 18, 8, 14, 10, 16, 6, 12]
        return heights[index % heights.count]
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func downloadAndPlay() {
        guard let storagePath = message.voiceStoragePath else { return }

        isDownloading = true

        Task {
            do {
                let audioData = try await SupabaseStorageService.shared.downloadVoiceMessage(from: storagePath)

                let fileManager = FileManager.default
                let voiceMessagesDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("voice_messages", isDirectory: true)

                try? fileManager.createDirectory(at: voiceMessagesDir, withIntermediateDirectories: true)

                let filename = message.voiceFilename ?? "\(message.id.uuidString).m4a"
                let localURL = voiceMessagesDir.appendingPathComponent(filename)

                try audioData.write(to: localURL)

                await MainActor.run {
                    downloadedLocalURL = localURL
                    isDownloading = false
                    audioPlayer.play(url: localURL)
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                }
                print("Failed to download voice message: \(error)")
            }
        }
    }
}

// MARK: - Inline Task List Card

struct InlineTaskListCard: View {
    let tasks: [ChatCardData.CardTask]
    let messageId: UUID
    var viewModel: ChatViewModel?

    private var completedCount: Int { tasks.filter { $0.isCompleted }.count }
    private var progress: Double { tasks.isEmpty ? 0 : Double(completedCount) / Double(tasks.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 32, height: 32)
                    Image(systemName: "checklist")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.7))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tâches du jour")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black.opacity(0.85))
                    Text("\(completedCount) sur \(tasks.count) terminées")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.8))
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if tasks.isEmpty {
                Text("Aucune tâche pour aujourd'hui")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                // Tasks
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    Button {
                        viewModel?.toggleTaskCompletion(messageId: messageId, taskId: task.id)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(task.isCompleted ? Color.clear : Color.black.opacity(0.15), lineWidth: 1.5)
                                    .frame(width: 24, height: 24)

                                if task.isCompleted {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.black)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.system(size: 15, weight: task.isCompleted ? .regular : .semibold))
                                    .foregroundColor(task.isCompleted ? .black.opacity(0.3) : .black.opacity(0.85))
                                    .strikethrough(task.isCompleted, color: .black.opacity(0.2))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                if let minutes = task.estimatedMinutes, minutes > 0 && !task.isCompleted {
                                    Text("\(minutes) min")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.black.opacity(0.35))
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }

                    if index < tasks.count - 1 {
                        Rectangle()
                            .fill(Color.black.opacity(0.05))
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Inline Routine List Card

struct InlineRoutineListCard: View {
    let routines: [ChatCardData.CardRoutine]
    let messageId: UUID
    var viewModel: ChatViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "repeat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                Text("Rituels")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(routines.filter { $0.isCompleted }.count)/\(routines.count)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if routines.isEmpty {
                Text("Aucun rituel configuré")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                // Routines
                ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                    Button {
                        viewModel?.toggleRoutineCompletion(messageId: messageId, routineId: routine.id)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(routine.isCompleted ? Color.clear : Color.black.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)

                                if routine.isCompleted {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            Text(routine.icon)
                                .font(.system(size: 16))

                            Text(routine.title)
                                .font(.system(size: 15, weight: routine.isCompleted ? .regular : .medium))
                                .foregroundColor(routine.isCompleted ? .black.opacity(0.3) : .black.opacity(0.85))
                                .strikethrough(routine.isCompleted, color: .black.opacity(0.2))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                    }

                    if index < routines.count - 1 {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 50)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Inline Planning Card (Tasks + Routines combined)

struct InlinePlanningCard: View {
    let tasks: [ChatCardData.CardTask]
    let routines: [ChatCardData.CardRoutine]
    let focusState: ChatCardData.PlanningFocusState?
    let messageId: UUID
    var viewModel: ChatViewModel?

    @State private var selectedDuration: Int = 25
    @State private var showCustomDuration = false
    @State private var customMinutes: String = ""
    @State private var customFocusTitle: String = ""
    @State private var showConfetti = false

    private var totalItems: Int { tasks.count + routines.count }
    private var completedItems: Int {
        tasks.filter { $0.isCompleted }.count + routines.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let focus = focusState, focus.timerState == .running || focus.timerState == .paused {
                timerActiveView(focus: focus)
            } else if let focus = focusState, focus.timerState == .completed {
                completedView(focus: focus)
            } else {
                normalPlanningView
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .onAppear {
            if let focus = focusState {
                selectedDuration = focus.duration
            }
        }
    }

    // MARK: - Normal / Idle Planning View

    @ViewBuilder
    private var normalPlanningView: some View {
        // Header
        HStack(spacing: 8) {
            Image(systemName: focusState != nil ? "flame.fill" : "checklist")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(focusState != nil ? .orange : .black.opacity(0.5))
            Text(focusState != nil ? "Session Focus" : "Planning")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
            if focusState == nil && totalItems > 0 {
                Text("\(completedItems)/\(totalItems)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)

        if tasks.isEmpty && routines.isEmpty {
            Text("Aucune tâche ni rituel")
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        } else {
            // Tasks section
            if !tasks.isEmpty {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    HStack(spacing: 0) {
                        Button {
                            viewModel?.toggleTaskCompletion(messageId: messageId, taskId: task.id)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(task.isCompleted ? Color.clear : Color.black.opacity(0.2), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                    if task.isCompleted {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.black)
                                            .frame(width: 22, height: 22)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                Text(task.title)
                                    .font(.system(size: 15, weight: task.isCompleted ? .regular : .medium))
                                    .foregroundColor(task.isCompleted ? .black.opacity(0.3) : .black.opacity(0.85))
                                    .strikethrough(task.isCompleted, color: .black.opacity(0.2))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                        }
                        // Focus button on each task (only in focus mode, idle state, non-completed tasks)
                        if focusState != nil && !task.isCompleted {
                            Button {
                                viewModel?.selectTaskForFocus(messageId: messageId, taskId: task.id, taskTitle: task.title)
                                if let est = task.estimatedMinutes, est > 0 {
                                    selectedDuration = est
                                }
                            } label: {
                                Image(systemName: focusState?.activeTaskId == task.id ? "flame.fill" : "flame")
                                    .font(.system(size: 16))
                                    .foregroundColor(focusState?.activeTaskId == task.id ? .orange : .black.opacity(0.2))
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 16)

                    if index < tasks.count - 1 || !routines.isEmpty {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 50)
                    }
                }
            }

            // Routines section (hidden during focus mode to save space)
            if !routines.isEmpty && focusState == nil {
                if !tasks.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "repeat")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black.opacity(0.35))
                        Text("Rituels")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black.opacity(0.35))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                }

                ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                    Button {
                        viewModel?.toggleRoutineCompletion(messageId: messageId, routineId: routine.id)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(routine.isCompleted ? Color.clear : Color.black.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if routine.isCompleted {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Text(routine.icon)
                                .font(.system(size: 16))
                            Text(routine.title)
                                .font(.system(size: 15, weight: routine.isCompleted ? .regular : .medium))
                                .foregroundColor(routine.isCompleted ? .black.opacity(0.3) : .black.opacity(0.85))
                                .strikethrough(routine.isCompleted, color: .black.opacity(0.2))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                    }
                    if index < routines.count - 1 {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 50)
                    }
                }
            }
            Spacer().frame(height: 4)
        }

        // Focus controls (duration + start button) — only in focus/idle mode
        if let focus = focusState, focus.timerState == .idle {
            focusIdleControls(focus: focus)
        }
    }

    // MARK: - Focus Idle Controls (duration chips + start)

    private func focusIdleControls(focus: ChatCardData.PlanningFocusState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)

            // Duration chips
            VStack(alignment: .leading, spacing: 6) {
                Text("Durée")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    ForEach([25, 50, 90], id: \.self) { minutes in
                        Button {
                            selectedDuration = minutes
                            showCustomDuration = false
                            viewModel?.updateFocusDuration(messageId: messageId, duration: minutes)
                        } label: {
                            Text("\(minutes) min")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(selectedDuration == minutes && !showCustomDuration ? .white : .black.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedDuration == minutes && !showCustomDuration ? Color.black : Color.black.opacity(0.06))
                                .cornerRadius(12)
                        }
                    }

                    Button {
                        showCustomDuration = true
                    } label: {
                        if showCustomDuration {
                            HStack(spacing: 4) {
                                TextField("", text: $customMinutes)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .keyboardType(.numberPad)
                                    .frame(width: 30)
                                    .multilineTextAlignment(.center)
                                    .onChange(of: customMinutes) { _, newValue in
                                        if let val = Int(newValue), val > 0 {
                                            selectedDuration = val
                                            viewModel?.updateFocusDuration(messageId: messageId, duration: val)
                                        }
                                    }
                                Text("min")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .cornerRadius(12)
                        } else {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.06))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Free subject field (when no task selected)
            if focus.activeTaskId == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sujet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black.opacity(0.4))
                        .padding(.horizontal, 16)

                    TextField("Sur quoi tu veux focus ?", text: $customFocusTitle)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.04))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                }
            }

            // Start button
            Button {
                viewModel?.startInlineFocusTimer(
                    messageId: messageId,
                    taskId: focus.activeTaskId,
                    taskTitle: focus.activeTaskId != nil ? focus.activeTaskTitle : (customFocusTitle.isEmpty ? nil : customFocusTitle),
                    duration: selectedDuration
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Commencer")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Timer Active View (running / paused)

    private func timerActiveView(focus: ChatCardData.PlanningFocusState) -> some View {
        let isPaused = focus.timerState == .paused
        return VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                Text(isPaused ? "En pause" : "Focus en cours")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if let title = focus.activeTaskTitle {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black.opacity(0.4))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Progress ring + countdown
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: timerProgress(focus: focus))
                    .stroke(
                        isPaused ? Color.orange : Color.black,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: focus.timeRemaining)

                VStack(spacing: 2) {
                    Text(formattedTime(focus: focus))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)

                    if isPaused {
                        Text("pause")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(width: 140, height: 140)

            // Controls
            HStack(spacing: 20) {
                Button {
                    viewModel?.stopInlineFocusTimer(messageId: messageId)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Circle())
                }

                Button {
                    if isPaused {
                        viewModel?.resumeInlineFocusTimer(messageId: messageId)
                    } else {
                        viewModel?.pauseInlineFocusTimer(messageId: messageId)
                    }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Completed View

    private func completedView(focus: ChatCardData.PlanningFocusState) -> some View {
        VStack(spacing: 14) {
            if showConfetti {
                InlineConfettiView()
                    .frame(height: 60)
            }

            VStack(spacing: 6) {
                Text("🔥")
                    .font(.system(size: 40))
                Text("Session terminée !")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                Text("\(focus.duration) minutes de focus")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.5))
            }
            .padding(.top, 16)

            if focus.activeTaskId != nil, let title = focus.activeTaskTitle {
                VStack(spacing: 10) {
                    Text("Tu as terminé « \(title) » ?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button {
                            viewModel?.validateFocusTimerTask(messageId: messageId, completed: false)
                        } label: {
                            Text("Pas encore")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.06))
                                .cornerRadius(12)
                        }

                        Button {
                            viewModel?.validateFocusTimerTask(messageId: messageId, completed: true)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Oui !")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                    }
                }
            } else {
                Button {
                    viewModel?.validateFocusTimerTask(messageId: messageId, completed: false)
                } label: {
                    Text("Fermer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.06))
                        .cornerRadius(12)
                }
            }

            Spacer().frame(height: 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showConfetti = true
            }
        }
    }

    // MARK: - Helpers

    private func timerProgress(focus: ChatCardData.PlanningFocusState) -> Double {
        let total = Double(focus.duration * 60)
        guard total > 0, let remaining = focus.timeRemaining else { return 0 }
        return 1.0 - (Double(remaining) / total)
    }

    private func formattedTime(focus: ChatCardData.PlanningFocusState) -> String {
        let remaining = focus.timeRemaining ?? 0
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Inline Confetti View

struct InlineConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, rotation: Double)] = []

    private let colors: [Color] = [.orange, .yellow, .red, .green, .blue, .purple]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(particle.color)
                        .frame(width: 6, height: 10)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                for i in 0..<20 {
                    let x = CGFloat.random(in: 0...geo.size.width)
                    particles.append((
                        id: i,
                        x: x,
                        y: -10,
                        color: colors.randomElement()!,
                        rotation: Double.random(in: 0...360)
                    ))
                }

                withAnimation(.easeIn(duration: 1.2)) {
                    for i in particles.indices {
                        particles[i].y = CGFloat.random(in: 20...60)
                        particles[i].rotation += Double.random(in: 90...270)
                    }
                }

                // Fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        particles.removeAll()
                    }
                }
            }
        }
    }
}

// MARK: - Video Suggestions Card

struct VideoSuggestionsCard: View {
    let data: ChatCardData.VideoSuggestionsData
    let messageId: UUID
    var viewModel: ChatViewModel?

    private var categoryLabel: String {
        switch data.category {
        case "meditation": return "Méditation"
        case "breathing": return "Respiration"
        case "motivation": return "Motivation"
        case "prayer": return "Prière"
        default: return data.category.capitalized
        }
    }

    private var categoryIcon: String {
        switch data.category {
        case "meditation": return "brain.head.profile"
        case "breathing": return "wind"
        case "motivation": return "bolt.fill"
        case "prayer": return "hands.sparkles.fill"
        default: return "play.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                Text("Vidéos de \(categoryLabel)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Video list
            ForEach(Array(data.videos.enumerated()), id: \.element.id) { index, video in
                HStack(spacing: 12) {
                    // YouTube thumbnail
                    AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(video.videoId)/mqdefault.jpg")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.black.opacity(0.3))
                                )
                        default:
                            Rectangle()
                                .fill(Color.black.opacity(0.05))
                                .overlay(ProgressView().tint(.black.opacity(0.3)))
                        }
                    }
                    .frame(width: 100, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Title + duration
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.85))
                            .lineLimit(2)
                        Text(video.duration)
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.4))
                    }

                    Spacer()

                    // Choose button
                    Button {
                        viewModel?.selectSuggestedVideo(messageId: messageId, video: video)
                    } label: {
                        Text("Choisir")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if index < data.videos.count - 1 {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.leading, 128)
                }
            }

            Spacer().frame(height: 6)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Inline Video Card

struct InlineVideoCard: View {
    let video: ChatCardData.VideoCard
    let messageId: UUID
    var viewModel: ChatViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                if video.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Terminé")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // YouTube Player (tap to play in Safari)
            YouTubePlayerView(videoId: video.videoId)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)

            // "J'ai fini" button
            if !video.isCompleted {
                Button {
                    viewModel?.videoCompleted(messageId: messageId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("J'ai fini la vidéo")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.black.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }

            Spacer().frame(height: 4)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - YouTube Player (WKWebView with Safari user-agent)

struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String

    /// Bundle-ID origin — WKWebView sends this as HTTP Referer, which YouTube requires for embeds
    private static let origin: String = {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jep.volta"
        return "https://\(bundleID)".lowercased()
    }()

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
            * { margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
            iframe { width: 100%; height: 100%; border: none; }
        </style>
        </head>
        <body>
        <iframe
            src="https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0&modestbranding=1&origin=\(Self.origin)"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen>
        </iframe>
        </body>
        </html>
        """

        // baseURL sets the security origin → WKWebView sends it as Referer header to YouTube
        webView.loadHTMLString(html, baseURL: URL(string: Self.origin))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                // Allow YouTube embed, API, and media resources
                if url.contains("youtube.com/embed") ||
                   url.contains("youtube-nocookie.com/embed") ||
                   url.contains("youtube.com/iframe_api") ||
                   url.contains("accounts.google.com") ||
                   url.contains("ytimg.com") ||
                   url.contains("googlevideo.com") ||
                   url.contains("google.com/recaptcha") ||
                   url.contains("gstatic.com") ||
                   url.hasPrefix(Self.bundleOrigin) ||
                   navigationAction.navigationType == .other {
                    decisionHandler(.allow)
                    return
                }
            }
            decisionHandler(.cancel)
        }

        private static let bundleOrigin: String = {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.jep.volta"
            return "https://\(bundleID)".lowercased()
        }()
    }
}

// MARK: - Typing Dots Animation

struct TypingDotsView: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .offset(y: dotOffsets[index])
            }
        }
        .onAppear {
            for i in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
                ) {
                    dotOffsets[i] = -5
                }
            }
        }
    }
}

// MARK: - Productivity Diagnostic Card

struct ProductivityDiagnosticCard: View {
    let data: ChatCardData.ProductivityDiagnosticData
    var viewModel: ChatViewModel?

    @State private var selectedIds: Set<String> = []
    @State private var isSubmitted: Bool = false

    private let maxTotalSelections = 5
    private let accentBlue = Color(red: 0.20, green: 0.45, blue: 1.0)

    private var isRecapStep: Bool { data.categoryIndex >= 5 }

    // Icons per category
    private static let categoryIcons: [String: String] = [
        "Énergie & Focus": "bolt.fill",
        "Blocages émotionnels": "heart.fill",
        "Organisation & Méthode": "list.bullet.clipboard.fill",
        "Motivation & Sens": "flame.fill",
        "Environnement & Hygiène de vie": "leaf.fill",
        "Récapitulatif": "checkmark.seal.fill",
    ]

    // How many already selected before this category
    private var previouslySelectedCount: Int {
        data.selectedIds.filter { id in !data.challenges.contains { $0.id == id } }.count
    }

    private var totalSelected: Int {
        previouslySelectedCount + selectedIds.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: Self.categoryIcons[data.categoryName] ?? "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentBlue)

                Text(data.categoryName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)

                Spacer()

                if !isSubmitted && !data.isSubmitted {
                    // Step indicator for categories (1-5), or total count for recap
                    if isRecapStep {
                        Text("\(data.selectedIds.count) sélectionnés")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    } else {
                        Text("Étape \(data.categoryIndex + 1)/5")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if isSubmitted || data.isSubmitted {
                // Submitted state — show selected items as compact summary
                submittedView
            } else if isRecapStep {
                // Recap step — show all selected with final validate button
                recapView
            } else {
                // Category step — show challenges for this category
                categorySelectionView
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .onAppear {
            if data.isSubmitted {
                isSubmitted = true
                selectedIds = Set(data.selectedIds)
            } else {
                // Pre-select any items from this category that were in previousSelections
                selectedIds = Set(data.selectedIds.filter { id in data.challenges.contains { $0.id == id } })
            }
        }
    }

    // MARK: - Submitted State

    private var submittedView: some View {
        let displayChallenges = data.challenges.filter { selectedIds.contains($0.id) || data.selectedIds.contains($0.id) }
        return VStack(alignment: .leading, spacing: 8) {
            if displayChallenges.isEmpty {
                Text("Aucun sélectionné — passé")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            } else {
                ForEach(displayChallenges) { challenge in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(accentBlue)
                        Text(challenge.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Category Selection (Carousel)

    private var categorySelectionView: some View {
        VStack(spacing: 0) {
            // Horizontal carousel — one symptom per slide
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(data.challenges) { challenge in
                        challengeSlide(challenge)
                            .frame(width: 240)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 12)

            // Selection summary
            if !selectedIds.isEmpty {
                HStack(spacing: 4) {
                    ForEach(data.challenges.filter { selectedIds.contains($0.id) }) { challenge in
                        Text(challenge.emoji)
                            .font(.system(size: 18))
                            .frame(width: 32, height: 32)
                            .background(accentBlue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // "Next" button
            Button(action: {
                HapticFeedback.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSubmitted = true
                }
                let allSelected = data.selectedIds.filter { id in
                    !data.challenges.contains { $0.id == id }
                } + Array(selectedIds)
                viewModel?.advanceDiagnostic(fromCategoryIndex: data.categoryIndex, selectedIds: allSelected)
            }) {
                HStack(spacing: 8) {
                    Text(selectedIds.isEmpty ? "Rien ici, suivant" : "Suivant (\(selectedIds.count) choisis)")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(accentBlue)
                .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Recap View

    @State private var recapSelectedIds: Set<String> = []
    @State private var recapInitialized = false

    private var tooManySelected: Bool {
        recapSelectedIds.count > maxTotalSelections
    }

    private var recapView: some View {
        VStack(spacing: 0) {
            if data.selectedIds.isEmpty {
                Text("Tu n'as rien sélectionné. Tu peux quand même valider — on apprendra en discutant.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else {
                if tooManySelected {
                    Text("Tu as sélectionné \(recapSelectedIds.count) défis — garde les 5 qui te parlent le plus.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data.challenges) { challenge in
                        let isKept = recapSelectedIds.contains(challenge.id)
                        Button(action: {
                            HapticFeedback.selection()
                            if isKept {
                                recapSelectedIds.remove(challenge.id)
                            } else {
                                recapSelectedIds.insert(challenge.id)
                            }
                        }) {
                            HStack(spacing: 10) {
                                Text(challenge.emoji)
                                    .font(.system(size: 20))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(challenge.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(isKept ? .black : .gray)
                                    Text(challenge.category)
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray.opacity(0.7))
                                }

                                Spacer()

                                Image(systemName: isKept ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(isKept ? accentBlue : .gray.opacity(0.3))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            // Final validate button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSubmitted = true
                }
                viewModel?.submitDiagnostic(selectedIds: Array(recapSelectedIds))
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                    Text("Valider mon diagnostic")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(tooManySelected ? Color.gray.opacity(0.4) : accentBlue)
                .cornerRadius(14)
            }
            .disabled(tooManySelected)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onAppear {
            if !recapInitialized {
                recapSelectedIds = Set(data.selectedIds)
                recapInitialized = true
            }
        }
    }

    // MARK: - Challenge Slide (Carousel card)

    private func challengeSlide(_ challenge: ChatCardData.ProductivityChallenge) -> some View {
        let isSelected = selectedIds.contains(challenge.id)

        return VStack(spacing: 12) {
            Text(challenge.emoji)
                .font(.system(size: 40))

            Text(challenge.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(isSelected ? .white : .black)
                .multilineTextAlignment(.center)

            Text(challenge.description)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Selection indicator
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text(isSelected ? "Sélectionné" : "Ça me parle")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white.opacity(0.9) : accentBlue)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(isSelected ? accentBlue : Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? accentBlue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.selection()
            if isSelected {
                selectedIds.remove(challenge.id)
            } else {
                selectedIds.insert(challenge.id)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - App Blocking Banner

struct AppBlockingBanner: View {
    @State private var elapsedSeconds: Int = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text("Apps bloquées")
                .font(.satoshi(13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text("·")
                .foregroundColor(.white.opacity(0.4))

            Text(formatElapsed(elapsedSeconds))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "#1A1B21"))
        .cornerRadius(20)
        .onReceive(timer) { _ in
            elapsedSeconds += 1
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Audio Player Manager

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0

    deinit {
        timer?.invalidate()
        audioPlayer?.stop()
    }

    func play(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Audio file not found at: \(url.path)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                self.progress = player.currentTime / player.duration
            }
        } catch {
            print("Playback error: \(error)")
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        currentTime = 0
        timer?.invalidate()
    }
}

// MARK: - Voice Recorder Manager

class VoiceRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?

    @Published var isRecording = false

    deinit {
        audioRecorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("voice_\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            audioURL = audioFilename
            isRecording = true
        } catch {
            print("Recording failed: \(error)")
        }
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return audioURL
    }
}

// MARK: - Settings Page View (full screen wrapper for fade transition)

struct SettingsPageView: View {
    var onDismiss: () -> Void
    @EnvironmentObject var store: FocusAppStore

    var body: some View {
        SettingsView(onDismiss: onDismiss)
            .environmentObject(store)
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .environmentObject(FocusAppStore.shared)
        .environmentObject(SubscriptionManager.shared)
}
