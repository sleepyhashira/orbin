import SwiftUI

struct InspectorView: View {
    let file: FileItem?
    @ObservedObject var thumbnails: ThumbnailProvider
    let onReveal: (FileItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let file {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Thumbnail preview ──
                        preview(file)
                            .padding(.bottom, 14)

                        // ── Filename ──
                        Text(file.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .padding(.bottom, 6)

                        // ── Category badges ──
                        HStack(spacing: 6) {
                            Text(file.effectiveCategory.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.obsidianOnPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.obsidianPrimaryContainer, in: RoundedRectangle(cornerRadius: 4))

                            if file.isAIClassified {
                                HStack(spacing: 3) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 8))
                                    Text("AI")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(Color.obsidianPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.obsidianPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                                .help("Category predicted by Qwen AI")
                            }
                        }
                        .padding(.bottom, 16)

                        // ── Metadata rows ──
                        VStack(alignment: .leading, spacing: 14) {
                            metadataRow(label: "KIND", value: file.typeDescription)
                            metadataRow(label: "SIZE", value: Formatters.fileSize(file.size))
                            metadataRow(label: "MODIFIED", value: file.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-")
                            metadataRow(label: "PATH", value: file.relativePath)

                            if file.isAIClassified && file.aiOverridesHeuristic {
                                metadataRow(label: "RULE-BASED", value: file.category.rawValue)
                            }
                        }
                    }
                    .padding(16)
                }

                Spacer()

                // ── Reveal in Finder — pinned at bottom ──
                Button {
                    onReveal(file)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                        Text("Reveal in Finder")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(Color.obsidianOnPrimary)
                    .background(
                        LinearGradient(
                            colors: [Color.obsidianPrimary, Color.obsidianPrimaryContainer],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
                .padding(16)

            } else {
                PlaceholderView(title: "Select a file", systemImage: "sidebar.right")
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.obsidianSurfaceContainer)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.obsidianGlassBorder),
            alignment: .leading
        )
    }

    // MARK: - Preview thumbnail

    private func preview(_ file: FileItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.obsidianSurfaceContainerLowest)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.obsidianGlassBorder, lineWidth: 1)
                )

            if let image = thumbnails.thumbnails[file.id] {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            } else {
                Image(systemName: file.category.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.obsidianSecondary.opacity(0.6))
            }
        }
        .aspectRatio(1.4, contentMode: .fit)
        .onAppear {
            thumbnails.thumbnail(for: file, size: CGSize(width: 420, height: 320))
        }
    }

    // MARK: - Metadata Row

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.obsidianOutline)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}
