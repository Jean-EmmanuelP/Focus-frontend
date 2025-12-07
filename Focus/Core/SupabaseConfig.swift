import Foundation

// MARK: - Supabase Configuration
enum SupabaseConfig {

    // MARK: - Load from Config.plist
    private static var config: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            // Return empty config if file not found (will use defaults)
            print("⚠️ Config.plist not found. Using default configuration.")
            return [:]
        }
        return dict
    }()

    static var supabaseURL: URL {
        guard let urlString = config["SUPABASE_URL"] as? String,
              !urlString.contains("your-project-id"),
              let url = URL(string: urlString) else {
            // Return placeholder URL - will fail gracefully
            return URL(string: "https://placeholder.supabase.co")!
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = config["SUPABASE_ANON_KEY"] as? String,
              !key.contains("your-anon-key") else {
            return "placeholder-key"
        }
        return key
    }

    static var isConfigured: Bool {
        guard let urlString = config["SUPABASE_URL"] as? String,
              let key = config["SUPABASE_ANON_KEY"] as? String else {
            return false
        }
        return !urlString.contains("your-project-id") && !key.contains("your-anon-key")
    }
}
