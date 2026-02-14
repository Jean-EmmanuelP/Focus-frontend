import SwiftUI
import PhotosUI

/// User profile view for Knowledge (Vous section) - Replika style
struct UserKnowledgeProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var knowledgeManager = KnowledgeManager.shared

    @State private var showNameEditor = false
    @State private var showPronounsSelector = false
    @State private var showBirthdayPicker = false
    @State private var showPhotoOptions = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            // Background gradient (purple/blue like Replika)
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.24),
                    Color(red: 0.05, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                navigationBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Photo section
                        photoSection

                        // Title
                        Text("Vous")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)

                        // Info cards
                        infoCardsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }

                // Bottom tabs placeholder
                bottomTabBar
            }
        }
        .sheet(isPresented: $showNameEditor) {
            NameEditorView(
                currentName: knowledgeManager.knowledge.userProfile.name ?? "",
                onSave: { name in
                    knowledgeManager.updateUserName(name)
                }
            )
        }
        .sheet(isPresented: $showPronounsSelector) {
            PronounsSelectorView(
                currentPronouns: knowledgeManager.knowledge.userProfile.pronouns,
                onSelect: { pronouns in
                    knowledgeManager.updateUserPronouns(pronouns)
                }
            )
        }
        .sheet(isPresented: $showBirthdayPicker) {
            BirthdayPickerView(
                currentDate: knowledgeManager.knowledge.userProfile.birthday,
                onSave: { date in
                    knowledgeManager.updateUserBirthday(date)
                }
            )
        }
        .sheet(isPresented: $showPhotoOptions) {
            PhotoOptionsSheet(
                onLibrarySelected: {},
                onCameraSelected: {}
            )
            .presentationDetents([.height(220)])
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 16) {
            Text("Ajoutez une photo, afin que \(FocusAppStore.shared.user?.companionName ?? "ton coach") puisse vous reconnaître à l'avenir")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Photo circle with dashed border
            Button(action: { showPhotoOptions = true }) {
                ZStack {
                    Circle()
                        .stroke(
                            Color.white.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                        )
                        .frame(width: 180, height: 180)

                    if knowledgeManager.knowledge.userProfile.photoURL != nil {
                        // Show photo if exists
                        Circle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 170, height: 170)
                    }

                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Info Cards Section

    private var infoCardsSection: some View {
        HStack(spacing: 12) {
            // Name card
            infoCard(
                title: "Nom",
                value: knowledgeManager.knowledge.userProfile.name ?? "Ajouter",
                action: { showNameEditor = true }
            )

            // Pronouns card
            infoCard(
                title: "Pronoms",
                value: knowledgeManager.knowledge.userProfile.pronouns ?? "Ajouter",
                action: { showPronounsSelector = true }
            )

            // Birthday card
            infoCard(
                title: "Anniversaire",
                value: formattedBirthday,
                action: { showBirthdayPicker = true }
            )
        }
    }

    private var formattedBirthday: String {
        guard let birthday = knowledgeManager.knowledge.userProfile.birthday else {
            return "Ajouter"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: birthday)
    }

    private func infoCard(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }

    // MARK: - Bottom Tab Bar

    private var bottomTabBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 0) {
                tabButton(title: "Profil", isSelected: false)
                tabButton(title: "Connaissance", isSelected: true)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )

            // FAB placeholder
            Circle()
                .fill(Color.blue)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func tabButton(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
            )
    }
}

// MARK: - Name Editor View

struct NameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let currentName: String
    let onSave: (String) -> Void

    @State private var name: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("Votre nom")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("OK") {
                        onSave(name)
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
                .padding()

                TextField("", text: $name, prompt: Text("Entrez votre nom").foregroundColor(.white.opacity(0.4)))
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal)

                Spacer()
            }
        }
        .onAppear {
            name = currentName
        }
    }
}

// MARK: - Pronouns Selector View

struct PronounsSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    let currentPronouns: String?
    let onSelect: (String) -> Void

    let options = ["Il / Lui", "Elle", "Iels", "Autre"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Spacer()
                    Text("Vos pronoms")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()

                // Options
                VStack(spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            onSelect(option)
                            dismiss()
                        }) {
                            HStack {
                                Text(option)
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                Spacer()
                                if currentPronouns == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}

// MARK: - Birthday Picker View (Replika style wheel)

struct BirthdayPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let currentDate: Date?
    let onSave: (Date) -> Void

    @State private var selectedDay: Int = 1
    @State private var selectedMonth: Int = 1
    @State private var selectedYear: Int = 2000

    let days = Array(1...31)
    let months = ["janvier", "février", "mars", "avril", "mai", "juin",
                  "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
    let years = Array(1920...2010).reversed()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    Text("Votre date de naissance")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal)

                Text("Nous avons besoin de cette information pour rendre votre expérience plus pertinente et sécurisée.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // Wheel pickers
                HStack(spacing: 0) {
                    // Day picker
                    Picker("Jour", selection: $selectedDay) {
                        ForEach(days, id: \.self) { day in
                            Text("\(day)")
                                .tag(day)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    // Month picker
                    Picker("Mois", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(months[month - 1])
                                .tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 140)

                    // Year picker
                    Picker("Année", selection: $selectedYear) {
                        ForEach(Array(years), id: \.self) { year in
                            Text("\(year)")
                                .tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .padding(.horizontal, 20)
                )

                Spacer()

                // Save button
                Button(action: {
                    let components = DateComponents(year: selectedYear, month: selectedMonth, day: selectedDay)
                    if let date = Calendar.current.date(from: components) {
                        onSave(date)
                    }
                    dismiss()
                }) {
                    Text("Sauvegarder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if let date = currentDate {
                let components = Calendar.current.dateComponents([.day, .month, .year], from: date)
                selectedDay = components.day ?? 1
                selectedMonth = components.month ?? 1
                selectedYear = components.year ?? 2000
            }
        }
    }
}

// MARK: - Photo Options Sheet

struct PhotoOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onLibrarySelected: () -> Void
    let onCameraSelected: () -> Void

    var body: some View {
        ZStack {
            Color(white: 0.12).ignoresSafeArea()

            VStack(spacing: 16) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                Text("Ajouter une photo")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    Button(action: {
                        dismiss()
                        onLibrarySelected()
                    }) {
                        Text("Choisir dans la bibliothèque")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }

                    Button(action: {
                        dismiss()
                        onCameraSelected()
                    }) {
                        Text("Prendre une photo")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.05))
                            )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

#Preview {
    UserKnowledgeProfileView()
}
