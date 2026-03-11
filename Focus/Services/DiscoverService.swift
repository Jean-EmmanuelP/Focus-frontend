import Foundation

@MainActor
class DiscoverService {
    private let apiClient = APIClient.shared

    func fetchNearbyUsers(lat: Double, lon: Double, radiusKm: Int = 50) async throws -> [NearbyUser] {
        try await apiClient.request(
            endpoint: .discoverUsers(lat: lat, lon: lon, radius: radiusKm),
            method: .get
        )
    }
}
