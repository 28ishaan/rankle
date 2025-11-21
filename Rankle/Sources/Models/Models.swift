import Foundation
import SwiftUI

struct MediaItem: Identifiable, Codable, Hashable {
    enum MediaType: String, Codable { case image, video }
    let id: UUID
    var type: MediaType
    var filename: String

    init(id: UUID = UUID(), type: MediaType, filename: String) {
        self.id = id
        self.type = type
        self.filename = filename
    }
}

struct RankleItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var media: [MediaItem]

    init(id: UUID = UUID(), title: String, media: [MediaItem] = []) {
        self.id = id
        self.title = title
        self.media = media
    }
}

struct RankleList: Identifiable, Codable {
    let id: UUID
    var name: String
    var items: [RankleItem]
    var colorRGBA: RGBAColor
    // Collaborative lists
    var isCollaborative: Bool = false
    var ownerId: UUID = UUID()
    var collaborators: [CollaboratorRanking] = []
    // List type
    var listType: ListType = .regular
    // Tier assignments: maps item ID to tier letter (only for tier lists)
    var tierAssignments: [UUID: String] = [:]

    init(id: UUID = UUID(), name: String, items: [RankleItem] = [], color: Color = .cyan, isCollaborative: Bool = false, listType: ListType = .regular) {
        self.id = id
        self.name = name
        self.items = items
        self.colorRGBA = RGBAColor(color: color)
        self.isCollaborative = isCollaborative
        self.listType = listType
    }

    var color: Color {
        get { colorRGBA.color }
        set { colorRGBA = RGBAColor(color: newValue) }
    }
    
    // Get items in a specific tier (for tier lists)
    func itemsInTier(_ tier: Tier) -> [RankleItem] {
        guard listType == .tier else { return [] }
        return items.filter { tierAssignments[$0.id] == tier.rawValue }
    }
    
    // Get unassigned items (for tier lists)
    var unassignedItems: [RankleItem] {
        guard listType == .tier else { return [] }
        return items.filter { tierAssignments[$0.id] == nil }
    }
}

struct CollaboratorRanking: Identifiable, Codable, Hashable {
    let id: UUID
    var userId: UUID
    var displayName: String?
    // Order of item ids representing the user's personal ranking
    var ranking: [UUID]
    var updatedAt: Date

    init(id: UUID = UUID(), userId: UUID, displayName: String? = nil, ranking: [UUID], updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.ranking = ranking
        self.updatedAt = updatedAt
    }
}

struct RGBAColor: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(color: Color) {
        let ui = UIColor(color)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        self.r = Double(rr)
        self.g = Double(gg)
        self.b = Double(bb)
        self.a = Double(aa)
    }

    var color: Color { Color(red: r, green: g, blue: b).opacity(a) }
}

struct Matchup: Codable, Hashable {
    let left: RankleItem
    let right: RankleItem
}

enum MatchupChoice: String, Codable {
    case left
    case right
}

enum ListType: String, Codable {
    case regular
    case tier
}

enum Tier: String, Codable, CaseIterable, Identifiable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var color: Color {
        switch self {
        case .s: return .purple
        case .a: return .red
        case .b: return .orange
        case .c: return .yellow
        case .d: return .green
        case .f: return .gray
        }
    }
}
