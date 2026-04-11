import SwiftUI

// MARK: - Create Challenge Sheet

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ChallengeType = .wakeup
    @State private var alarmTime = Date()
    @State private var durationDays = 30
    @State private var customTitle = ""
    @State private var isCreating = false

    var onCreate: (ChallengeType, String, Int, String?) -> Void

    private let bgColor = Color(red: 0.10, green: 0.12, blue: 0.20)

    var body: some View {
        NavigationView {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Type selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Type de challenge")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .kerning(1)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 10) {
                                ForEach(ChallengeType.allCases, id: \.self) { type in
                                    Button {
                                        selectedType = type
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 22))
                                            Text(type.title)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(selectedType == type ? .white : .white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedType == type ? typeColor(type).opacity(0.3) : Color.white.opacity(0.06))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedType == type ? typeColor(type) : .clear, lineWidth: 1.5)
                                        )
                                    }
                                }
                            }
                        }

                        // Custom title (for custom type)
                        if selectedType == .custom {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nom du challenge")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)

                                TextField("Ex: Courir 5km", text: $customTitle)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Time picker (for wake-up)
                        if selectedType == .wakeup {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Heure de réveil")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)

                                DatePicker("", selection: $alarmTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .frame(height: 120)
                            }
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Durée")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)

                            HStack(spacing: 8) {
                                ForEach([7, 14, 30], id: \.self) { days in
                                    Button {
                                        durationDays = days
                                    } label: {
                                        Text("\(days) jours")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(durationDays == days ? .white : .white.opacity(0.4))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(durationDays == days ? typeColor(selectedType).opacity(0.4) : Color.white.opacity(0.06))
                                            )
                                    }
                                }
                            }
                        }

                        // Info
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.white.opacity(0.3))
                            Text("Après création, partage le challenge avec un ami pour le lancer.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Create button
                        Button {
                            isCreating = true
                            let h = Calendar.current.component(.hour, from: alarmTime)
                            let m = Calendar.current.component(.minute, from: alarmTime)
                            let timeStr = String(format: "%02d:%02d", h, m)
                            let title = selectedType == .custom ? customTitle : nil
                            onCreate(selectedType, timeStr, durationDays, title)
                        } label: {
                            HStack {
                                if isCreating {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "bolt.fill")
                                    Text("Créer le challenge")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(typeColor(selectedType))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isCreating || (selectedType == .custom && customTitle.isEmpty))
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nouveau Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func typeColor(_ type: ChallengeType) -> Color {
        switch type {
        case .wakeup: return .orange
        case .gym: return .red
        case .meditation: return .purple
        case .reading: return .blue
        case .custom: return .green
        }
    }
}
