import SwiftUI

struct JournalListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [JournalEntryResponse] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedEntry: JournalEntryResponse?
    @State private var hasMore = true
    @State private var currentOffset = 0

    private let pageSize = 20

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                if isLoading && entries.isEmpty {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let error = error, entries.isEmpty {
                    errorView(error)
                } else if entries.isEmpty {
                    emptyStateView
                } else {
                    entriesListView
                }
            }
            .navigationTitle("journal.history".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                NavigationStack {
                    JournalEntryView(entry: entry) {
                        Task {
                            await deleteEntry(entry)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("close".localized) {
                                selectedEntry = nil
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadEntries()
        }
    }

    // MARK: - Entries List
    private var entriesListView: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.md) {
                ForEach(groupedEntries, id: \.key) { month, monthEntries in
                    Section {
                        ForEach(monthEntries) { entry in
                            JournalEntryRow(entry: entry)
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                                .onAppear {
                                    if entry.id == entries.last?.id && hasMore {
                                        Task {
                                            await loadMoreEntries()
                                        }
                                    }
                                }
                        }
                    } header: {
                        Text(month)
                            .font(.headline)
                            .foregroundColor(ColorTokens.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, SpacingTokens.md)
                    }
                }

                if isLoading && !entries.isEmpty {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, SpacingTokens.xl)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(ColorTokens.textMuted)

            Text("journal.empty_history".localized)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ColorTokens.textPrimary)

            Text("journal.empty_history_subtitle".localized)
                .font(.body)
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
    }

    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(ColorTokens.error)

            Text(message)
                .font(.body)
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            Button("retry".localized) {
                Task {
                    await loadEntries()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Grouped Entries
    private var groupedEntries: [(key: String, value: [JournalEntryResponse])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: entries) { entry -> String in
            if let date = formatter.date(from: entry.entryDate) {
                return monthFormatter.string(from: date)
            }
            return "Unknown"
        }

        return grouped.sorted { first, second in
            let firstDate = monthFormatter.date(from: first.key) ?? Date.distantPast
            let secondDate = monthFormatter.date(from: second.key) ?? Date.distantPast
            return firstDate > secondDate
        }
    }

    // MARK: - Data Loading
    private func loadEntries() async {
        isLoading = true
        error = nil
        currentOffset = 0

        do {
            let service = JournalService()
            let response = try await service.fetchEntries(limit: pageSize, offset: 0)
            entries = response.entries
            hasMore = response.entries.count == pageSize
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func loadMoreEntries() async {
        guard !isLoading && hasMore else { return }

        isLoading = true
        currentOffset += pageSize

        do {
            let service = JournalService()
            let response = try await service.fetchEntries(limit: pageSize, offset: currentOffset)
            entries.append(contentsOf: response.entries)
            hasMore = response.entries.count == pageSize
        } catch {
            currentOffset -= pageSize
        }

        isLoading = false
    }

    private func deleteEntry(_ entry: JournalEntryResponse) async {
        do {
            let service = JournalService()
            try await service.deleteEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
            selectedEntry = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Journal Entry Row
struct JournalEntryRow: View {
    let entry: JournalEntryResponse

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            // Mood emoji
            Text(entry.moodEmoji)
                .font(.title)
                .frame(width: 50, height: 50)
                .background(moodColor.opacity(0.1))
                .cornerRadius(RadiusTokens.md)

            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                // Title or date
                Text(entry.title ?? formattedDate)
                    .font(.headline)
                    .foregroundColor(ColorTokens.textPrimary)
                    .lineLimit(1)

                // Summary preview
                if let summary = entry.summary {
                    Text(summary.replacingOccurrences(of: "\n", with: " "))
                        .font(.subheadline)
                        .foregroundColor(ColorTokens.textSecondary)
                        .lineLimit(2)
                }

                // Date and duration
                HStack(spacing: SpacingTokens.sm) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(ColorTokens.textMuted)

                    Text("•")
                        .foregroundColor(ColorTokens.textMuted)

                    Text(entry.formattedDuration)
                        .font(.caption)
                        .foregroundColor(ColorTokens.textMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ColorTokens.textMuted)
        }
        .padding()
        .background(ColorTokens.surface)
        .cornerRadius(RadiusTokens.lg)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: entry.entryDate) else { return entry.entryDate }
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var moodColor: Color {
        switch entry.mood {
        case "great": return .green
        case "good": return .blue
        case "neutral": return .gray
        case "low": return .orange
        case "bad": return .red
        default: return .gray
        }
    }
}

#Preview {
    JournalListView()
}
