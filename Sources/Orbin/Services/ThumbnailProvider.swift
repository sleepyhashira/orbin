import AppKit
import Foundation
import QuickLookThumbnailing

@MainActor
final class ThumbnailProvider: ObservableObject {
    @Published private(set) var thumbnails: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    func thumbnail(for file: FileItem, size: CGSize = CGSize(width: 96, height: 96)) {
        guard thumbnails[file.id] == nil, !inFlight.contains(file.id) else { return }
        inFlight.insert(file.id)

        let request = QLThumbnailGenerator.Request(
            fileAt: file.url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(file.id)
                if let image = representation?.nsImage {
                    self.thumbnails[file.id] = image
                }
            }
        }
    }
}
