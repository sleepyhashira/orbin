import Foundation
import UniformTypeIdentifiers

struct FileScanner {
    func scan(rootURL: URL, progress: @escaping @Sendable (Int) -> Void) async throws -> [FileItem] {
        try await Task.detached(priority: .userInitiated) {
            let keys: [URLResourceKey] = [
                .isRegularFileKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .typeIdentifierKey,
                .localizedTypeDescriptionKey
            ]

            guard let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else {
                return []
            }

            var files: [FileItem] = []
            var scanned = 0

            while let url = enumerator.nextObject() as? URL {
                try Task.checkCancellation()
                let values = try? url.resourceValues(forKeys: Set(keys))
                guard values?.isRegularFile == true else { continue }

                let typeIdentifier = values?.typeIdentifier
                let category = FileClassifier.category(for: url, typeIdentifier: typeIdentifier)
                let item = FileItem(
                    id: url.path,
                    url: url,
                    name: url.lastPathComponent,
                    relativePath: Self.relativePath(for: url, rootURL: rootURL),
                    size: Int64(values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate,
                    category: category,
                    typeDescription: values?.localizedTypeDescription ?? typeIdentifier ?? "Unknown"
                )

                files.append(item)
                scanned += 1

                if scanned.isMultiple(of: 50) {
                    progress(scanned)
                }
            }

            progress(scanned)
            return files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }.value
    }

    private static func relativePath(for url: URL, rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return url.lastPathComponent }

        let start = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        return String(filePath[start...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
