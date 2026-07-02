import Foundation

struct FileItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let relativePath: String
    let size: Int64
    let modifiedAt: Date?
    let category: FileCategory
    let typeDescription: String

    // AI-classification fields (populated asynchronously by OllamaClassifier)
    var aiCategory: FileCategory?
    var aiConfidence: Double?

    /// True once Qwen has responded for this file.
    var isAIClassified: Bool { aiCategory != nil }

    /// True when Qwen disagrees with the rule-based classifier.
    var aiOverridesHeuristic: Bool {
        guard let ai = aiCategory else { return false }
        return ai != category
    }

    /// The best available category: AI result if present, otherwise rule-based.
    var effectiveCategory: FileCategory { aiCategory ?? category }

    var parentDirectory: URL {
        url.deletingLastPathComponent()
    }

    var displayExtension: String {
        let ext = url.pathExtension
        return ext.isEmpty ? "No extension" : ext.uppercased()
    }
}

struct ScanSummary {
    var totalSize: Int64
    var fileCount: Int
    var categories: [FileCategory: Int]
    var largestFiles: [FileItem]
    var aiClassifiedCount: Int = 0

    static let empty = ScanSummary(totalSize: 0, fileCount: 0, categories: [:], largestFiles: [], aiClassifiedCount: 0)
}

struct DuplicateGroup: Identifiable, Hashable {
    let id: String
    let hash: String
    let size: Int64
    let files: [FileItem]
}

enum SidebarSelection: Hashable {
    case overview
    case category(FileCategory)
    case largeFiles
    case duplicates
}
