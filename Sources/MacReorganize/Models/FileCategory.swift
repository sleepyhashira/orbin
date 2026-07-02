import Foundation
import UniformTypeIdentifiers

enum FileCategory: String, CaseIterable, Identifiable, Comparable {
    case images = "Images"
    case documents = "Documents"
    case audio = "Audio"
    case video = "Video"
    case archives = "Archives"
    case code = "Code"
    case applications = "Applications"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .images: "photo"
        case .documents: "doc.text"
        case .audio: "waveform"
        case .video: "film"
        case .archives: "archivebox"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .applications: "app"
        case .other: "questionmark.folder"
        }
    }

    static func < (lhs: FileCategory, rhs: FileCategory) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .images: 0
        case .documents: 1
        case .audio: 2
        case .video: 3
        case .archives: 4
        case .code: 5
        case .applications: 6
        case .other: 7
        }
    }
}

enum FileClassifier {
    static func category(for url: URL, typeIdentifier: String?) -> FileCategory {
        if let typeIdentifier, let type = UTType(typeIdentifier) {
            if type.conforms(to: .image) { return .images }
            if type.conforms(to: .audio) { return .audio }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
            if type.conforms(to: .archive) { return .archives }
            if type.conforms(to: .application) { return .applications }
            if type.conforms(to: .sourceCode) || type.conforms(to: .script) { return .code }
            if type.conforms(to: .pdf) || type.conforms(to: .text) || type.conforms(to: .rtf) || type.conforms(to: .presentation) || type.conforms(to: .spreadsheet) {
                return .documents
            }
        }

        switch url.pathExtension.lowercased() {
        case "swift", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "java", "c", "cc", "cpp", "h", "hpp", "json", "yaml", "yml", "toml", "html", "css", "scss":
            return .code
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg":
            return .archives
        case "doc", "docx", "pages", "xls", "xlsx", "numbers", "ppt", "pptx", "key":
            return .documents
        default:
            return .other
        }
    }

    /// Parse a free-text category name returned by an LLM into a typed FileCategory.
    /// Matches case-insensitively and handles common synonyms Qwen might produce.
    static func fromAIResponse(_ text: String) -> FileCategory? {
        let normalised = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            // strip surrounding punctuation/quotes
            .trimmingCharacters(in: CharacterSet.punctuationCharacters)

        switch normalised {
        case "images", "image", "photo", "photos", "picture", "pictures":
            return .images
        case "documents", "document", "docs", "doc", "text", "pdf", "spreadsheet", "presentation":
            return .documents
        case "audio", "music", "sound", "sounds":
            return .audio
        case "video", "videos", "movie", "movies", "film", "films":
            return .video
        case "archives", "archive", "compressed", "zip":
            return .archives
        case "code", "source", "source code", "script", "scripts", "programming":
            return .code
        case "applications", "application", "app", "apps", "executable":
            return .applications
        case "other", "unknown", "misc", "miscellaneous":
            return .other
        default:
            // Fuzzy fallback: check if any category rawValue is contained
            return FileCategory.allCases.first {
                normalised.contains($0.rawValue.lowercased())
            }
        }
    }
}
