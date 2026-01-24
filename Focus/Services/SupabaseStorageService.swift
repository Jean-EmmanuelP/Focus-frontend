import Foundation

/// Service for uploading/downloading files to/from Supabase Storage
@MainActor
class SupabaseStorageService {
    static let shared = SupabaseStorageService()

    private let bucketName = "voice-messages"

    private var storageURL: URL {
        URL(string: "\(SupabaseConfig.supabaseURL.absoluteString)/storage/v1")!
    }

    private init() {}

    // MARK: - Upload Voice Message

    /// Upload a voice message to Supabase Storage
    /// - Parameters:
    ///   - audioData: The audio file data
    ///   - userId: The user's ID (used as folder name)
    /// - Returns: The public URL of the uploaded file
    func uploadVoiceMessage(audioData: Data, userId: String) async throws -> String {
        let filename = "\(UUID().uuidString).m4a"
        let path = "\(userId)/\(filename)"

        guard let token = await AuthService.shared.getAccessToken() else {
            throw StorageError.notAuthenticated
        }

        let uploadURL = storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(path)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            // Return the storage path (we'll construct full URL when needed)
            let storagePath = "\(bucketName)/\(path)"
            print("✅ Voice message uploaded: \(storagePath)")
            return storagePath
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            print("❌ Upload failed: HTTP \(httpResponse.statusCode) - \(errorBody)")
            throw StorageError.uploadFailed(httpResponse.statusCode)
        }
    }

    // MARK: - Get Signed URL

    /// Get a signed URL for a private file (valid for 1 hour)
    func getSignedURL(for path: String) async throws -> URL {
        guard let token = await AuthService.shared.getAccessToken() else {
            throw StorageError.notAuthenticated
        }

        // Remove bucket name prefix if present
        let cleanPath = path.hasPrefix("\(bucketName)/")
            ? String(path.dropFirst(bucketName.count + 1))
            : path

        let signURL = storageURL
            .appendingPathComponent("object")
            .appendingPathComponent("sign")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(cleanPath)

        var request = URLRequest(url: signURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Request 1 hour expiry
        let body = ["expiresIn": 3600]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StorageError.signedURLFailed
        }

        struct SignedURLResponse: Decodable {
            let signedURL: String
        }

        let decoded = try JSONDecoder().decode(SignedURLResponse.self, from: data)

        guard let signedURL = URL(string: decoded.signedURL) else {
            throw StorageError.invalidURL
        }

        return signedURL
    }

    // MARK: - Download Voice Message

    /// Download a voice message from Supabase Storage
    func downloadVoiceMessage(from path: String) async throws -> Data {
        let signedURL = try await getSignedURL(for: path)

        let (data, response) = try await URLSession.shared.data(from: signedURL)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StorageError.downloadFailed
        }

        return data
    }

    // MARK: - Delete Voice Message

    func deleteVoiceMessage(path: String) async throws {
        guard let token = await AuthService.shared.getAccessToken() else {
            throw StorageError.notAuthenticated
        }

        let cleanPath = path.hasPrefix("\(bucketName)/")
            ? String(path.dropFirst(bucketName.count + 1))
            : path

        let deleteURL = storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(cleanPath)

        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw StorageError.deleteFailed
        }
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case uploadFailed(Int)
    case downloadFailed
    case signedURLFailed
    case invalidURL
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidResponse:
            return "Invalid response from storage"
        case .uploadFailed(let code):
            return "Upload failed with status \(code)"
        case .downloadFailed:
            return "Download failed"
        case .signedURLFailed:
            return "Failed to get signed URL"
        case .invalidURL:
            return "Invalid URL"
        case .deleteFailed:
            return "Delete failed"
        }
    }
}
