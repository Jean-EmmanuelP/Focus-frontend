import Foundation

// MARK: - Focus Room Category

enum FocusRoomCategory: String, CaseIterable, Codable, Identifiable {
    case sport
    case travail
    case etudes
    case creativite
    case lecture
    case meditation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sport: return "Sport"
        case .travail: return "Travail"
        case .etudes: return "Etudes"
        case .creativite: return "Creativite"
        case .lecture: return "Lecture"
        case .meditation: return "Meditation"
        }
    }

    var icon: String {
        switch self {
        case .sport: return "figure.run"
        case .travail: return "laptopcomputer"
        case .etudes: return "book.fill"
        case .creativite: return "paintbrush.fill"
        case .lecture: return "text.book.closed.fill"
        case .meditation: return "brain.head.profile"
        }
    }
}

// MARK: - Focus Room

struct FocusRoom: Codable, Identifiable {
    let id: String
    let category: String
    let livekitRoomName: String
    let maxParticipants: Int
    let createdAt: Date
    let participants: [RoomParticipant]
}

// MARK: - Room Participant

struct RoomParticipant: Codable, Identifiable {
    let id: String
    let pseudo: String?
    let firstName: String?
    let avatarUrl: String?
    let joinedAt: Date
}

// MARK: - Join Room Request / Response

struct JoinRoomRequest: Encodable {
    let category: String
}

struct JoinRoomResponse: Decodable {
    let room: FocusRoom
    let token: String
    let url: String?
}
