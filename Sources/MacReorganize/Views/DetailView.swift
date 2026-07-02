import SwiftUI

struct DetailView: View {
    @ObservedObject var store: OrganizerStore
    @ObservedObject var thumbnails: ThumbnailProvider
    @State private var targetFolderName = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HSplitView {
            mainPane
                .frame(minWidth: 500)

            InspectorView(file: store.selectedFile, thumbnails: thumbnails, onReveal: store.revealInFinder)
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
        }
        .background(Color.obsidianSurface)
    }

    private var mainPane: some View {
        VStack(spacing: 0) {
            if store.rootURL == nil {
                EmptyStateView(action: store.chooseFolder)
            } else {
                headerSection
                statsCards
                actionBar
                FileTableView(files: store.filteredFiles, selectedFile: $store.selectedFile, thumbnails: thumbnails, onReveal: store.revealInFinder)
            }
        }
        .background(Color.obsidianSurface)
    }

    // MARK: - Header (path + title)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Path breadcrumb
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.obsidianSecondary)
                Text(store.rootURL?.path ?? "")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.obsidianSecondary)
                    .lineLimit(1)
            }

            Text(sectionTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Stats Cards Row

    private var statsCards: some View {
        HStack(spacing: 12) {

            // ── File Distribution card ──
            HStack(alignment: .center, spacing: 14) {
                // Legend
                VStack(alignment: .leading, spacing: 6) {
                    Text("File Distribution")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.bottom, 2)

                    let slices = distributionSlices
                    ForEach(slices.prefix(5)) { slice in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 8, height: 8)
                            Text("\(slice.label) (\(pct(slice.count, of: store.summary.fileCount)))")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color.obsidianOnSurface)
                        }
                    }
                }

                Spacer()

                // Donut chart
                FileDistributionChart(
                    files: store.filteredFiles.isEmpty ? store.files : store.filteredFiles,
                    selection: store.selection
                )
                .frame(width: 110, height: 110)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.obsidianSurfaceContainerHigh)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.obsidianGlassBorder, lineWidth: 1)
                    )
            )

            // ── Right stat cards ──
            VStack(spacing: 12) {
                statCard(label: "TOTAL SIZE", value: Formatters.fileSize(store.summary.totalSize))
                statCard(label: "DUPLICATES", value: "\(store.duplicateGroups.reduce(0) { $0 + $1.files.count })")
            }
            .frame(width: 160)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.3), value: store.selection)
        .animation(.easeInOut(duration: 0.3), value: store.files.count)
    }

    // MARK: - Action Bar (table header + actions)

    private var actionBar: some View {
        let isMoveDisabled = targetFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.filteredFiles.isEmpty
        return HStack(spacing: 8) {
            Text("Files in Directory")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            Text(store.status.message)
                .font(.system(size: 11))
                .foregroundStyle(Color.obsidianSecondary)

            // Move controls
            TextField("Folder name", text: $targetFolderName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.obsidianSurfaceContainerLowest)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isFieldFocused ? Color.obsidianPrimary : Color.obsidianOutlineVariant, lineWidth: 1)
                )
                .focused($isFieldFocused)
                .frame(width: 140)
                .help("Enter the subfolder name to move files into.")

            Button {
                store.moveSelectedFilesToNewFolder(named: targetFolderName)
                targetFolderName = ""
            } label: {
                Label("Move", systemImage: "folder")
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: isMoveDisabled))
            .disabled(isMoveDisabled)

            if store.selection == .duplicates {
                Button(role: .destructive) {
                    store.trashDuplicateCopies()
                } label: {
                    Label("Trash", systemImage: "trash")
                }
                .buttonStyle(DestructiveButtonStyle(isDisabled: store.duplicateGroups.isEmpty))
                .disabled(store.duplicateGroups.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.obsidianSurfaceContainerLow)
    }

    // MARK: - Helpers

    private var sectionTitle: String {
        switch store.selection {
        case .overview: "Overview"
        case .category(let category): category.rawValue
        case .largeFiles: "Large Files"
        case .duplicates: "Duplicates"
        }
    }

    private var distributionSlices: [ChartSlice] {
        let files = store.filteredFiles.isEmpty ? store.files : store.filteredFiles
        let grouped = Dictionary(grouping: files, by: \.effectiveCategory)
        return FileCategory.allCases.compactMap { cat -> ChartSlice? in
            let items = grouped[cat] ?? []
            guard !items.isEmpty else { return nil }
            return ChartSlice(
                id: cat.rawValue,
                label: cat.rawValue,
                count: items.count,
                bytes: items.reduce(0) { $0 + $1.size },
                color: cat.chartColor
            )
        }
        .sorted { $0.count > $1.count }
    }

    private func pct(_ count: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int(round(Double(count) / Double(total) * 100)))%"
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.obsidianOutline)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.obsidianSurfaceContainerHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.obsidianGlassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.obsidianSecondary.opacity(0.5))
            Text("Choose a folder to scan")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color.obsidianOnSurface)
            Button(action: action) {
                Label("Open Folder", systemImage: "folder")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
