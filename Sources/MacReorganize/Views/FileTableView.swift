import SwiftUI

struct FileTableView: View {
    let files: [FileItem]
    @Binding var selectedFile: FileItem?
    @ObservedObject var thumbnails: ThumbnailProvider
    let onReveal: (FileItem) -> Void

    var body: some View {
        Table(files, selection: selectionBinding) {
            TableColumn("Name") { file in
                HStack(spacing: 10) {
                    ThumbnailView(file: file, thumbnails: thumbnails)
                        .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(file.name)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(file.relativePath)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.obsidianSecondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .contextMenu {
                    Button("Reveal in Finder") {
                        onReveal(file)
                    }
                }
            }

            TableColumn("Kind") { file in
                Text(file.typeDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.obsidianSecondary)
            }
            .width(min: 110, ideal: 140)

            TableColumn("Size") { file in
                Text(Formatters.fileSize(file.size))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Modified") { file in
                Text(file.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.obsidianSecondary)
            }
            .width(min: 100, ideal: 130)
        }
        .overlay {
            if files.isEmpty {
                PlaceholderView(title: "No files in this view", systemImage: "tray")
            }
        }
    }

    private var selectionBinding: Binding<Set<String>> {
        Binding {
            if let selectedFile {
                return [selectedFile.id]
            }
            return []
        } set: { ids in
            guard let id = ids.first else {
                selectedFile = nil
                return
            }
            selectedFile = files.first { $0.id == id }
        }
    }
}

// MARK: - Thumbnail cell

private struct ThumbnailView: View {
    let file: FileItem
    @ObservedObject var thumbnails: ThumbnailProvider

    var body: some View {
        Group {
            if let image = thumbnails.thumbnails[file.id] {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: file.category.systemImage)
                    .foregroundStyle(Color.obsidianSecondary)
                    .font(.system(size: 14))
            }
        }
        .padding(3)
        .background(Color.obsidianSurfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.obsidianGlassBorder, lineWidth: 1)
        )
        .onAppear {
            thumbnails.thumbnail(for: file, size: CGSize(width: 60, height: 60))
        }
    }
}
