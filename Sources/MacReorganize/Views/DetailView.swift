import SwiftUI

struct DetailView: View {
    @ObservedObject var store: OrganizerStore
    @ObservedObject var thumbnails: ThumbnailProvider
    @State private var targetFolderName = ""

    var body: some View {
        HSplitView {
            mainPane
                .frame(minWidth: 540)

            InspectorView(file: store.selectedFile, thumbnails: thumbnails, onReveal: store.revealInFinder)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
        }
    }

    private var mainPane: some View {
        VStack(spacing: 0) {
            HeaderView(store: store)

            if store.rootURL == nil {
                EmptyStateView(action: store.chooseFolder)
            } else {
                actionBar
                FileTableView(files: store.filteredFiles, selectedFile: $store.selectedFile, thumbnails: thumbnails, onReveal: store.revealInFinder)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            TextField("New folder name", text: $targetFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .help("Enter the subfolder name that the current view will be moved into.")

            Button {
                store.moveSelectedFilesToNewFolder(named: targetFolderName)
                targetFolderName = ""
            } label: {
                Label("Move Current View", systemImage: "folder")
            }
            .disabled(targetFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.filteredFiles.isEmpty)
            .help("Move every file currently shown in the table into the named subfolder.")

            if store.selection == .duplicates {
                Button(role: .destructive) {
                    store.trashDuplicateCopies()
                } label: {
                    Label("Trash Duplicate Copies", systemImage: "trash")
                }
                .disabled(store.duplicateGroups.isEmpty)
                .help("Keep the first file in each duplicate group and move the remaining copies to Trash.")
            }

            Spacer()

            Text(store.status.message)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct HeaderView: View {
    @ObservedObject var store: OrganizerStore

    var body: some View {
        HStack(alignment: .top, spacing: 20) {

            // ── Left: title + stat pills ──────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if case .scanning = store.status {
                        ProgressView()
                            .controlSize(.small)
                            .help("Folder scan is running.")
                    }
                }

                HStack(spacing: 16) {
                    StatPill(title: "Files", value: "\(store.summary.fileCount)")
                    StatPill(title: "Size", value: Formatters.fileSize(store.summary.totalSize))
                    StatPill(title: "Duplicates", value: "\(store.duplicateGroups.reduce(0) { $0 + $1.files.count })")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── Right: pie chart ─────────────────────────────────────────
            if store.rootURL != nil && !store.files.isEmpty {
                Divider()
                FileDistributionChart(
                    files: store.filteredFiles.isEmpty ? store.files : store.filteredFiles,
                    selection: store.selection
                )
                .frame(minWidth: 260, maxWidth: 340)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: store.selection)
                .animation(.easeInOut(duration: 0.3), value: store.files.count)
            }
        }
        .padding(20)
    }

    private var title: String {
        switch store.selection {
        case .overview: "Overview"
        case .category(let category): category.rawValue
        case .largeFiles: "Large Files"
        case .duplicates: "Duplicates"
        }
    }

    private var subtitle: String {
        store.rootURL?.path ?? "No folder selected"
    }
}


private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .frame(minWidth: 96, alignment: .leading)
    }
}

private struct EmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Choose a folder to scan")
                .font(.title3)
                .fontWeight(.medium)
            Button(action: action) {
                Label("Open Folder", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .help("Choose a folder to scan.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
