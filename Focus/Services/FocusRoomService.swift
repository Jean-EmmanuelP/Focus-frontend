import Foundation

@MainActor
class FocusRoomService {
    private let apiClient = APIClient.shared

    func joinRoom(category: FocusRoomCategory) async throws -> JoinRoomResponse {
        try await apiClient.request(
            endpoint: .joinFocusRoom,
            method: .post,
            body: JoinRoomRequest(category: category.rawValue)
        )
    }

    func leaveRoom(roomId: String) async throws {
        try await apiClient.request(
            endpoint: .leaveFocusRoom(roomId),
            method: .post
        )
    }

    func listRooms(category: String? = nil) async throws -> [FocusRoom] {
        try await apiClient.request(
            endpoint: .focusRooms(category: category),
            method: .get
        )
    }
}
