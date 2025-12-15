import SwiftUI

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: Double // 0.0 to 1.0
    var color: Color = ColorTokens.primaryStart
    var height: CGFloat = 8
    var showGlow: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(ColorTokens.surface)
                    .frame(height: height)
                
                // Progress fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * min(max(progress, 0), 1),
                        height: height
                    )
                    .shadow(
                        color: showGlow ? color.opacity(0.5) : .clear,
                        radius: 4,
                        x: 0,
                        y: 0
                    )
            }
        }
        .frame(height: height)
    }
}

// MARK: - Circular Progress (Level Badge)
struct LevelBadge: View {
    let level: Int
    let progress: Double
    var size: CGFloat = 120
    
    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ColorTokens.primaryGlow,
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.2, height: size * 1.2)
                .blur(radius: 10)
            
            // Background circle
            Circle()
                .stroke(ColorTokens.surface, lineWidth: 8)
                .frame(width: size, height: size)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ColorTokens.fireGradient,
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: ColorTokens.primaryGlow,
                    radius: 8,
                    x: 0,
                    y: 0
                )
            
            // Level content
            VStack(spacing: SpacingTokens.xs) {
                Text("LEVEL")
                    .label()
                    .foregroundColor(ColorTokens.textMuted)
                
                Text("\(level)")
                    .font(.satoshi(36, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
            }
        }
        .frame(width: size * 1.2, height: size * 1.2)
    }
}

// MARK: - Bar Chart
struct BarChart: View {
    let data: [DayProgress]
    var maxHeight: CGFloat = 120
    
    private var maxMinutes: Int {
        data.map { $0.minutes }.max() ?? 1
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.sm) {
            ForEach(data) { day in
                VStack(spacing: SpacingTokens.xs) {
                    // Bar
                    RoundedRectangle(cornerRadius: RadiusTokens.sm)
                        .fill(
                            day.date.isToday
                                ? ColorTokens.fireGradient
                                : LinearGradient(
                                    colors: [
                                        ColorTokens.primaryStart.opacity(0.6),
                                        ColorTokens.primaryEnd.opacity(0.6)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                        )
                        .frame(
                            height: maxHeight * (CGFloat(day.minutes) / CGFloat(maxMinutes))
                        )
                        .shadow(
                            color: day.date.isToday ? ColorTokens.primaryGlow : .clear,
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    // Day label
                    Text(day.day)
                        .caption()
                        .foregroundColor(
                            day.date.isToday
                                ? ColorTokens.textPrimary
                                : ColorTokens.textMuted
                        )
                        .fontWeight(day.date.isToday ? .bold : .regular)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: maxHeight + 30)
    }
}

// MARK: - Streak Badge
struct StreakBadge: View {
    let days: Int
    var compact: Bool = false
    
    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("🔥")
                .font(.system(size: compact ? 16 : 20))
            
            Text("\(days)")
                .font(.system(size: compact ? 14 : 16, weight: .bold))
                .foregroundColor(ColorTokens.textPrimary)
            
            if !compact {
                Text("days")
                    .caption()
                    .foregroundColor(ColorTokens.textMuted)
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.primarySoft)
        .cornerRadius(RadiusTokens.full)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.full)
                .stroke(ColorTokens.primaryStart.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Avatar
struct AvatarView: View {
    let name: String
    var avatarURL: String? = nil
    var size: CGFloat = 40
    var showBorder: Bool = true
    var allowZoom: Bool = false
    @State private var showingZoom = false

    private var initials: String {
        let components = name.split(separator: " ")
        let firstInitial = components.first?.first.map(String.init) ?? ""
        let lastInitial = components.count > 1 ? components.last?.first.map(String.init) ?? "" : ""
        return (firstInitial + lastInitial).uppercased()
    }

    var body: some View {
        ZStack {
            if let urlString = avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_):
                        initialsView
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .overlay(
            Circle()
                .stroke(
                    showBorder ? ColorTokens.border : Color.clear,
                    lineWidth: 2
                )
        )
        .if(allowZoom && avatarURL != nil) { view in
            view
                .contentShape(Circle())
                .onTapGesture {
                    showingZoom = true
                }
        }
        .fullScreenCover(isPresented: $showingZoom) {
            ZoomablePhotoView(imageURL: avatarURL, fallbackName: name)
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.fireGradient)
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Zoomable Photo View (Full Screen)
struct ZoomablePhotoView: View {
    let imageURL: String?
    let fallbackName: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let urlString = imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            let newScale = scale * delta
                                            scale = min(max(newScale, 1.0), 5.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            if scale < 1.0 {
                                                withAnimation { scale = 1.0 }
                                            }
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                    }
                                }
                            }
                    case .failure(_):
                        fallbackView
                    case .empty:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.satoshi(30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }

            // Instructions
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    Text("Pinch to zoom • Double tap to zoom")
                        .caption()
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, geometry.safeAreaInsets.bottom + SpacingTokens.lg)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.fireGradient)
                .frame(width: 200, height: 200)

            Text(initials)
                .font(.satoshi(80, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var initials: String {
        let components = fallbackName.split(separator: " ")
        let firstInitial = components.first?.first.map(String.init) ?? ""
        let lastInitial = components.count > 1 ? components.last?.first.map(String.init) ?? "" : ""
        return (firstInitial + lastInitial).uppercased()
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String = "Manage"

    var body: some View {
        HStack {
            Text(title)
                .subtitle()
                .fontWeight(.semibold)
                .foregroundColor(ColorTokens.textPrimary)
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .bodyText()
                        .foregroundColor(ColorTokens.primaryStart)
                }
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Text(icon)
                .font(.satoshi(64))
            
            VStack(spacing: SpacingTokens.sm) {
                Text(title)
                    .heading2()
                    .foregroundColor(ColorTokens.textPrimary)
                
                Text(subtitle)
                    .bodyText()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, action: action)
                    .padding(.horizontal, SpacingTokens.xl)
            }
        }
        .padding(SpacingTokens.xxl)
    }
}

// MARK: - Loading Indicator
struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ColorTokens.primaryStart))
                .scaleEffect(1.5)

            Text(message)
                .bodyText()
                .foregroundColor(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
    }
}

// MARK: - Flow Layout (for tags/chips)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x - spacing)
            }
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Preview
#Preview("Other Components") {
    ScrollView {
        VStack(spacing: SpacingTokens.xl) {
            ProgressBar(progress: 0.68)
                .frame(height: 8)
            
            LevelBadge(level: 7, progress: 0.68)
            
            BarChart(data: [
                DayProgress(day: "M", minutes: 75, date: Date()),
                DayProgress(day: "T", minutes: 120, date: Date()),
                DayProgress(day: "W", minutes: 90, date: Date()),
                DayProgress(day: "T", minutes: 150, date: Date()),
                DayProgress(day: "F", minutes: 110, date: Date()),
                DayProgress(day: "S", minutes: 60, date: Date()),
                DayProgress(day: "S", minutes: 142, date: Date())
            ])
            
            StreakBadge(days: 12)
            
            HStack {
                AvatarView(name: "Alex Smith")
                AvatarView(name: "John Doe", size: 60)
            }
            
            SectionHeader(title: "Daily Rituals", action: {}, actionTitle: "Manage")
            
            EmptyStateView(
                icon: "🎯",
                title: "No quests yet",
                subtitle: "Create your first quest to start tracking progress",
                actionTitle: "Create Quest",
                action: {}
            )
        }
        .padding()
    }
    .background(ColorTokens.background)
}
