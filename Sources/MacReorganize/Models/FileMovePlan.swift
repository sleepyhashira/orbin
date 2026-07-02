import Foundation

// MARK: - A single proposed file move

struct FileMovePlan: Identifiable, Hashable {
    let id: UUID
    let file: FileItem
    /// Suggested folder path relative to rootURL, e.g. "Finance" or "Photos/Vacations"
    let suggestedFolder: String
    /// Absolute destination URL
    let destinationURL: URL
    /// Whether this folder needs to be created
    let folderExists: Bool
    /// Whether the user has selected this move in the review sheet
    var isSelected: Bool = true

    var destinationFileURL: URL {
        destinationURL.appendingPathComponent(file.name)
    }

    static func == (lhs: FileMovePlan, rhs: FileMovePlan) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - A full reorganization plan (group of moves)

struct ReorganizePlan: Identifiable {
    let id = UUID()
    var moves: [FileMovePlan]

    var selectedMoves: [FileMovePlan] { moves.filter(\.isSelected) }
    var foldersToCreate: Set<URL> {
        Set(selectedMoves.filter { !$0.folderExists }.map(\.destinationURL))
    }

    var groupedByFolder: [(folder: String, moves: [FileMovePlan])] {
        let dict = Dictionary(grouping: moves, by: \.suggestedFolder)
        return dict
            .map { (folder: $0.key, moves: $0.value) }
            .sorted { $0.folder < $1.folder }
    }
}
