import SwiftUI
import FamilyControls
import Combine

/// ViewModel for the App Blocker settings view
@MainActor
class AppBlockerViewModel: ObservableObject {
    // Reference to the shared service
    private let appBlockerService = ScreenTimeAppBlockerService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State (mirrored from service)
    @Published var authorizationStatus: ScreenTimeAppBlockerService.AuthorizationStatus = .notDetermined
    @Published var isBlocking: Bool = false
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()

    // MARK: - UI State
    @Published var showAppPicker: Bool = false
    @Published var isRequestingAuthorization: Bool = false
    @Published var showAuthorizationError: Bool = false

    // MARK: - Settings (stored in UserDefaults)
    @Published var enableBlockingDuringFocus: Bool {
        didSet {
            UserDefaults.standard.set(enableBlockingDuringFocus, forKey: "appBlocker.enableDuringFocus")
        }
    }

    init() {
        // Load saved value from UserDefaults
        self.enableBlockingDuringFocus = UserDefaults.standard.bool(forKey: "appBlocker.enableDuringFocus")
        // Default to true if never set
        if !UserDefaults.standard.bool(forKey: "appBlocker.enableDuringFocus.hasBeenSet") {
            self.enableBlockingDuringFocus = true
            UserDefaults.standard.set(true, forKey: "appBlocker.enableDuringFocus.hasBeenSet")
        }
        setupBindings()
    }

    private func setupBindings() {
        // Observe service state changes
        appBlockerService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$authorizationStatus)

        appBlockerService.$isBlocking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isBlocking)

        appBlockerService.$selectedApps
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedApps)
    }

    // MARK: - Computed Properties

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    var hasSelectedApps: Bool {
        appBlockerService.hasSelectedApps
    }

    var selectedAppsCount: Int {
        appBlockerService.selectedAppsCount
    }

    var statusDescription: String {
        if !isAuthorized {
            return "Autorise l'accès pour bloquer les apps"
        } else if !hasSelectedApps {
            return "Aucune app sélectionnée"
        } else if isBlocking {
            return "Blocage actif (\(selectedAppsCount) apps)"
        } else {
            return "\(selectedAppsCount) app(s) sélectionnée(s)"
        }
    }

    var canShowPicker: Bool {
        isAuthorized
    }

    // MARK: - Actions

    /// Request Screen Time authorization
    func requestAuthorization() async {
        isRequestingAuthorization = true

        let success = await appBlockerService.requestAuthorization()

        isRequestingAuthorization = false

        if !success {
            showAuthorizationError = true
        }
    }

    /// Show the app picker (if authorized)
    func presentAppPicker() {
        guard isAuthorized else {
            Task {
                await requestAuthorization()
                if isAuthorized {
                    showAppPicker = true
                }
            }
            return
        }
        showAppPicker = true
    }

    /// Update selected apps from picker
    func updateSelection(_ selection: FamilyActivitySelection) {
        appBlockerService.updateSelectedApps(selection)
    }

    /// Clear all selected apps
    func clearSelection() {
        appBlockerService.clearSelection()
    }

    /// Start blocking manually (for testing)
    func startBlocking() {
        appBlockerService.startBlocking()
    }

    /// Stop blocking manually
    func stopBlocking() {
        appBlockerService.stopBlocking()
    }
}
