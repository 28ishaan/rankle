import Foundation

final class UserService {
    static let shared = UserService()
    private let key = "rankle_current_user_id"

    private(set) var currentUserId: UUID

    private init() {
        if let s = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: s) {
            currentUserId = id
        } else {
            let id = UUID()
            currentUserId = id
            UserDefaults.standard.set(id.uuidString, forKey: key)
        }
    }
}
