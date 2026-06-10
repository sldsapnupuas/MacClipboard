import Foundation

enum ClipboardItemKind: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: ClipboardItemKind
    var text: String?
    var imageData: Data?
    let date: Date
    var pinned: Bool

    static func text(_ string: String) -> ClipboardItem {
        ClipboardItem(id: UUID(), kind: .text, text: string, imageData: nil, date: Date(), pinned: false)
    }

    static func image(_ data: Data) -> ClipboardItem {
        ClipboardItem(id: UUID(), kind: .image, text: nil, imageData: data, date: Date(), pinned: false)
    }

    /// Single-line preview used in the history list.
    var preview: String {
        guard let text else { return "" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 300 ? String(trimmed.prefix(300)) + "…" : trimmed
    }
}
