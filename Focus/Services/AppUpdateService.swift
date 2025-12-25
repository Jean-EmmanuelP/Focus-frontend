import Foundation
import SwiftUI
import Combine

/// Service to check for app updates from the App Store
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()

    @Published var updateAvailable: Bool = false
    @Published var appStoreVersion: String?
    @Published var currentVersion: String
    @Published var appStoreURL: URL?

    // Your app's bundle ID
    private let bundleId = "com.jep.volta"

    // Your App Store ID (you'll get this after publishing)
    // For now, we can use bundleId lookup
    private let appStoreId: String? = nil // Set this after publishing, e.g., "1234567890"

    private init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Check if an update is available on the App Store
    @MainActor
    func checkForUpdate() async {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else {
            print("❌ AppUpdateService: Invalid URL")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ AppUpdateService: Bad response")
                return
            }

            let result = try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)

            guard let appInfo = result.results.first else {
                print("ℹ️ AppUpdateService: App not found on App Store (may not be published yet)")
                return
            }

            appStoreVersion = appInfo.version
            appStoreURL = URL(string: appInfo.trackViewUrl)

            // Compare versions
            if let storeVersion = appStoreVersion {
                updateAvailable = isVersion(storeVersion, newerThan: currentVersion)
                if updateAvailable {
                    print("🔄 AppUpdateService: Update available! Current: \(currentVersion), App Store: \(storeVersion)")
                } else {
                    print("✅ AppUpdateService: App is up to date (\(currentVersion))")
                }
            }
        } catch {
            print("❌ AppUpdateService: Error checking for update: \(error.localizedDescription)")
        }
    }

    /// Open the App Store page for the app
    func openAppStore() {
        guard let url = appStoreURL ?? URL(string: "https://apps.apple.com/app/id\(appStoreId ?? "")") else {
            return
        }

        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }

    /// Compare two version strings (e.g., "1.2.3" vs "1.2.4")
    private func isVersion(_ version1: String, newerThan version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Components.count, v2Components.count)

        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0

            if v1 > v2 {
                return true
            } else if v1 < v2 {
                return false
            }
        }

        return false // Versions are equal
    }
}

// MARK: - App Store API Response Models
private struct AppStoreLookupResponse: Decodable {
    let resultCount: Int
    let results: [AppStoreAppInfo]
}

private struct AppStoreAppInfo: Decodable {
    let version: String
    let trackViewUrl: String
    let trackName: String?
    let releaseNotes: String?
    let minimumOsVersion: String?
}
