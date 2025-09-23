import Foundation

struct RankleItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

struct RankleList: Identifiable, Codable {
    let id: UUID
    var name: String
    var items: [RankleItem]

    init(id: UUID = UUID(), name: String, items: [RankleItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}

struct Matchup: Codable, Hashable {
    let left: RankleItem
    let right: RankleItem
}

enum MatchupChoice: String, Codable {
    case left
    case right
}
