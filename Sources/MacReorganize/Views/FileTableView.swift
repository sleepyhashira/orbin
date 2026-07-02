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
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .lineLimit(1)
                        Text(file.relativePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                Label(file.category.rawValue, systemImage: file.category.systemImage)
            }
            .width(min: 120, ideal: 150)

            TableColumn("Size") { file in
                Text(Formatters.fileSize(file.size))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)

            TableColumn("Modified") { file in
                Text(file.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
            }
            .width(min: 120, ideal: 140)
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
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
        }
        .padding(3)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            thumbnails.thumbnail(for: file, size: CGSize(width: 68, height: 68))
        }
    }
}
