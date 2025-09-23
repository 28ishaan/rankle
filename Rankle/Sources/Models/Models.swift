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

    init(id: UUID = UUID(), name: String, items: [RankleItem] = [], color: Color = .cyan) {
        self.id = id
        self.name = name
        self.items = items
        self.colorRGBA = RGBAColor(color: color)
    }

    var color: Color {
        get { colorRGBA.color }
        set { colorRGBA = RGBAColor(color: newValue) }
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
