import Foundation
import UIKit

final class SharingService {
    static let shared = SharingService()
    
    // Generate shareable URL for Rankle users
    func generateDeepLink(for list: RankleList) -> URL? {
        guard let jsonData = try? JSONEncoder().encode(list) else { return nil }
        let base64 = jsonData.base64EncodedString()
        let urlString = "rankle://import?data=\(base64)"
        return URL(string: urlString)
    }
    
    // Generate clipboard text for non-Rankle users
    func generateClipboardText(for list: RankleList) -> String {
        var text = "📊 \(list.name)\n\n"
        for (index, item) in list.items.enumerated() {
            text += "\(index + 1). \(item.title)\n"
        }
        text += "\nShared from Rankle"
        return text
    }
    
    // Copy to clipboard
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    // Parse deep link data
    func parseDeepLink(url: URL) -> RankleList? {
        guard url.scheme == "rankle",
              url.host == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value,
              let jsonData = Data(base64Encoded: dataParam),
              let list = try? JSONDecoder().decode(RankleList.self, from: jsonData) else {
            return nil
        }
        return list
    }
}

