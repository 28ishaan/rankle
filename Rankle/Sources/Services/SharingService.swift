import Foundation
import UIKit
import Compression

final class SharingService {
    static let shared = SharingService()
    
    // MARK: - Public API
    // Generate compact deep link for Rankle users using compression + base64url token in path
    func generateDeepLink(for list: RankleList) -> URL? {
        guard let jsonData = try? JSONEncoder().encode(list) else { return nil }
        // Compress then base64url encode for shorter, clickable links
        let compressed = compress(jsonData)
        let token = base64URLEncode(compressed)
        // Use short host and path to minimize length
        let urlString = "rankle://i/\(token)"
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
    
    // Parse deep link data (supports old query format for backward compatibility)
    func parseDeepLink(url: URL) -> RankleList? {
        guard url.scheme == "rankle" else { return nil }
        // New format: rankle://i/<token>
        if url.host == "i" {
            let token = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let data = base64URLDecode(token) else { return nil }
            let json = decompress(data)
            return try? JSONDecoder().decode(RankleList.self, from: json)
        }
        // Legacy format: rankle://import?data=<base64>
        if url.host == "import",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value,
           let jsonData = Data(base64Encoded: dataParam) {
            return try? JSONDecoder().decode(RankleList.self, from: jsonData)
        }
        return nil
    }

    // MARK: - Encoding helpers
    private func base64URLEncode(_ data: Data) -> String {
        let b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return b64
    }

    private func base64URLDecode(_ string: String) -> Data? {
        // Restore padding
        var s = string.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - (s.count % 4)
        if pad < 4 { s.append(String(repeating: "=", count: pad)) }
        return Data(base64Encoded: s)
    }

    private func compress(_ data: Data) -> Data {
        // LZFSE encode using the simple one-shot API
        let dstCapacity = max(1024, data.count + data.count / 10 + 64)
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstCapacity)
        defer { dstBuffer.deallocate() }
        let count = data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_encode_buffer(dstBuffer, dstCapacity, srcPtr, data.count, nil, COMPRESSION_LZFSE)
        }
        guard count > 0 else { return data }
        return Data(bytes: dstBuffer, count: count)
    }

    private func decompress(_ data: Data) -> Data {
        // Try progressively larger buffers until decode succeeds
        var factor = 4
        while factor <= 64 {
            let dstCapacity = max(1024, data.count * factor)
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstCapacity)
            defer { dstBuffer.deallocate() }
            let count = data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(dstBuffer, dstCapacity, srcPtr, data.count, nil, COMPRESSION_LZFSE)
            }
            if count > 0 { return Data(bytes: dstBuffer, count: count) }
            factor *= 2
        }
        // Fallback to original data if decode fails
        return data
    }
}

