import CryptoKit
import Foundation

struct DuplicateFinder {
    func findDuplicates(in files: [FileItem]) async -> [DuplicateGroup] {
        let candidates = Dictionary(grouping: files.filter { $0.size > 0 }, by: \.size)
            .values
            .filter { $0.count > 1 }

        var hashBuckets: [String: [FileItem]] = [:]
        for bucket in candidates {
            for file in bucket {
                if Task.isCancelled { return [] }
                guard let hash = sha256(for: file.url) else { continue }
                hashBuckets[hash, default: []].append(file)
            }
        }

        return hashBuckets
            .compactMap { hash, files in
                guard files.count > 1, let first = files.first else { return nil }
                return DuplicateGroup(id: hash, hash: hash, size: first.size, files: files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
            }
            .sorted {
                if $0.size == $1.size { return $0.files.count > $1.files.count }
                return $0.size > $1.size
            }
    }

    private func sha256(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1024 * 1024)
            if data.isEmpty { return false }
            hasher.update(data: data)
            return true
        }) {}

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
