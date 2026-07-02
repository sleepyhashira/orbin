import SwiftUI

struct InspectorView: View {
    let file: FileItem?
    @ObservedObject var thumbnails: ThumbnailProvider
    let onReveal: (FileItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let file {
                preview(file)

                VStack(alignment: .leading, spacing: 10) {
                    Text(file.name)
                        .font(.headline)
                        .lineLimit(3)

                    MetadataRow(label: "Kind", value: file.typeDescription)

                    // Category row: show AI result if available
                    if file.isAIClassified {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Category")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(file.effectiveCategory.rawValue)
                                    .font(.callout)
                                Label("AI", systemImage: "sparkles")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.purple.opacity(0.12), in: Capsule())
                                    .help("Category predicted by Qwen AI")
                            }
                            if file.aiOverridesHeuristic {
                                Text("Rule-based: \(file.category.rawValue)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        MetadataRow(label: "Category", value: file.category.rawValue)
                    }

                    MetadataRow(label: "Size", value: Formatters.fileSize(file.size))
                    MetadataRow(label: "Modified", value: file.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-")
                    MetadataRow(label: "Path", value: file.relativePath)
                }

                Button {
                    onReveal(file)
                } label: {
                    Label("Reveal in Finder", systemImage: "magnifyingglass")
                }

                Spacer()
            } else {
                PlaceholderView(title: "Select a file", systemImage: "sidebar.right")
            }
        }
        .padding(18)
        .background(.regularMaterial)
    }

    private func preview(_ file: FileItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)

            if let image = thumbnails.thumbnails[file.id] {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            } else {
                Image(systemName: file.category.systemImage)
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1.35, contentMode: .fit)
        .onAppear {
            thumbnails.thumbnail(for: file, size: CGSize(width: 420, height: 320))
        }
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}
