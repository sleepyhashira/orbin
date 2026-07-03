import SwiftUI

struct AIPlanView: View {
    @ObservedObject var store: OrganizerStore
    @Environment(\.dismiss) private var dismiss

    // Local copy of the plan so we can mutate checkboxes without touching the store
    @State private var plan: ReorganizePlan

    init(store: OrganizerStore, plan: ReorganizePlan) {
        self.store = store
        self._plan = State(initialValue: plan)
    }

    private var selectedCount: Int { plan.selectedMoves.count }
    private var newFolderCount: Int { plan.foldersToCreate.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(Color.obsidianGlassBorder)
            planList
            Divider()
                .overlay(Color.obsidianGlassBorder)
            footer
        }
        .frame(minWidth: 620, minHeight: 480)
        .background(Color.obsidianBackground)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.largeTitle)
                .foregroundStyle(Color.obsidianPrimary)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 3) {
                Text("AI Reorganization Plan")
                    .font(.appHeadlineMedium())
                    .foregroundColor(.white)
                Text("Qwen suggests moving \(plan.moves.count) files into \(plan.groupedByFolder.count) folders. Review and deselect any moves you don't want, then apply.")
                    .font(.appBodySmall())
                    .foregroundStyle(Color.obsidianSecondary)
            }
            Spacer()
        }
        .padding(20)
        .background(Color.obsidianSurfaceContainerLow)
    }

    // MARK: - Plan List (grouped by destination folder)

    private var planList: some View {
        List {
            ForEach(plan.groupedByFolder, id: \.folder) { group in
                Section {
                    ForEach(group.moves.indices, id: \.self) { moveIdx in
                        // Find the absolute index in plan.moves
                        let globalIdx = plan.moves.firstIndex(where: { $0.id == group.moves[moveIdx].id })!
                        planRow(for: $plan.moves[globalIdx])
                    }
                } header: {
                    folderHeader(group.folder, moves: group.moves)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color.obsidianSurface)
    }

    @ViewBuilder
    private func folderHeader(_ name: String, moves: [FileMovePlan]) -> some View {
        HStack(spacing: 6) {
            let needsCreate = moves.contains { !$0.folderExists }
            Image(systemName: needsCreate ? "folder.badge.plus" : "folder")
                .foregroundStyle(needsCreate ? Color.obsidianPrimary : Color.obsidianSecondary)
            Text(name)
                .font(.appHeadlineSmall())
                .foregroundColor(.white)
            if needsCreate {
                Text("will be created")
                    .font(.appLabelCaps())
                    .foregroundStyle(Color.obsidianPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.obsidianPrimary.opacity(0.12), in: Capsule())
            }
            Spacer()
            Text("\(moves.count) file\(moves.count == 1 ? "" : "s")")
                .font(.appLabelCode())
                .foregroundStyle(Color.obsidianSecondary)
        }
    }

    private func planRow(for move: Binding<FileMovePlan>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: move.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)

            Image(systemName: move.wrappedValue.file.effectiveCategory.systemImage)
                .foregroundStyle(Color.obsidianSecondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(move.wrappedValue.file.name)
                    .font(.appBodyMedium())
                    .lineLimit(1)
                    .foregroundStyle(move.wrappedValue.isSelected ? Color.white : Color.obsidianSecondary)
                Text(move.wrappedValue.file.relativePath)
                    .font(.appLabelCode())
                    .foregroundStyle(Color.obsidianSecondary.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Arrow + destination
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(Color.obsidianSecondary)
                Text(move.wrappedValue.suggestedFolder)
                    .font(.appLabelCode())
                    .foregroundStyle(Color.obsidianPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.obsidianSurfaceContainerHigh, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                            .stroke(Color.obsidianGlassBorder, lineWidth: 1)
                    )
            }
            .opacity(move.wrappedValue.isSelected ? 1 : 0.4)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Footer

    private var footer: some View {
        let applyDisabled = selectedCount == 0
        return HStack(spacing: 12) {
            // Select all / none
            Button("Select All")  { setAll(true)  }
                .font(.appLabelCaps())
                .foregroundColor(Color.obsidianPrimary)
                .buttonStyle(.link)
            Button("Select None") { setAll(false) }
                .font(.appLabelCaps())
                .foregroundColor(Color.obsidianPrimary)
                .buttonStyle(.link)

            Spacer()

            // Summary
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(selectedCount) of \(plan.moves.count) moves selected")
                    .font(.appBodySmall())
                    .foregroundStyle(Color.obsidianSecondary)
                if newFolderCount > 0 {
                    Text("\(newFolderCount) new folder\(newFolderCount == 1 ? "" : "s") will be created")
                        .font(.appLabelCode())
                        .foregroundStyle(Color.obsidianPrimary)
                }
            }

            Button("Cancel") {
                store.discardReorganizePlan()
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
            .keyboardShortcut(.escape)

            Button("Apply \(selectedCount) Move\(selectedCount == 1 ? "" : "s")") {
                // Push selection state back to the store's plan before applying
                store.pendingPlan = plan
                store.applyReorganizePlan()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: applyDisabled))
            .disabled(applyDisabled)
            .keyboardShortcut(.return)
        }
        .padding(16)
        .background(Color.obsidianSurfaceContainerLow)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.obsidianGlassBorder),
            alignment: .top
        )
    }

    private func setAll(_ value: Bool) {
        for idx in plan.moves.indices {
            plan.moves[idx].isSelected = value
        }
    }
}
