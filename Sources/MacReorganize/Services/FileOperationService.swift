import Foundation

struct FileOperationService {
    func move(_ files: [FileItem], to destination: URL) throws -> [String] {
        var results: [String] = []

        for file in files {
            let target = uniqueDestination(for: file.url.lastPathComponent, in: destination)
            try FileManager.default.moveItem(at: file.url, to: target)
            results.append("\(file.url.path) -> \(target.path)")
        }

        return results
    }

    func trash(_ files: [FileItem]) throws -> [String] {
        var results: [String] = []

        for file in files {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: file.url, resultingItemURL: &resultingURL)
            results.append(file.url.path)
        }

        return results
    }

    func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        let proposed = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: proposed.path) else {
            return proposed
        }

        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        for index in 1...10_000 {
            let candidateName = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return directory.appendingPathComponent(UUID().uuidString + "-" + fileName)
    }
}
