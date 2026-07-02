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
            planList
            Divider()
            footer
        }
        .frame(minWidth: 620, minHeight: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.largeTitle)
                .foregroundStyle(.purple)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 3) {
                Text("AI Reorganization Plan")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Qwen suggests moving **\(plan.moves.count) files** into **\(plan.groupedByFolder.count) folders**. Review and deselect any moves you don't want, then apply.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(.regularMaterial)
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
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    @ViewBuilder
    private func folderHeader(_ name: String, moves: [FileMovePlan]) -> some View {
        HStack(spacing: 6) {
            let needsCreate = moves.contains { !$0.folderExists }
            Image(systemName: needsCreate ? "folder.badge.plus" : "folder")
                .foregroundStyle(needsCreate ? .purple : .secondary)
            Text(name)
                .fontWeight(.semibold)
            if needsCreate {
                Text("will be created")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.purple.opacity(0.1), in: Capsule())
            }
            Spacer()
            Text("\(moves.count) file\(moves.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func planRow(for move: Binding<FileMovePlan>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: move.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)

            Image(systemName: move.wrappedValue.file.effectiveCategory.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(move.wrappedValue.file.name)
                    .lineLimit(1)
                    .foregroundStyle(move.wrappedValue.isSelected ? .primary : .tertiary)
                Text(move.wrappedValue.file.relativePath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Arrow + destination
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(move.wrappedValue.suggestedFolder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
            .opacity(move.wrappedValue.isSelected ? 1 : 0.4)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            // Select all / none
            Button("Select All")  { setAll(true)  }.buttonStyle(.link)
            Button("Select None") { setAll(false) }.buttonStyle(.link)

            Spacer()

            // Summary
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(selectedCount) of \(plan.moves.count) moves selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if newFolderCount > 0 {
                    Text("\(newFolderCount) new folder\(newFolderCount == 1 ? "" : "s") will be created")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }

            Button("Cancel") {
                store.discardReorganizePlan()
                dismiss()
            }
            .keyboardShortcut(.escape)

            Button("Apply \(selectedCount) Move\(selectedCount == 1 ? "" : "s")") {
                // Push selection state back to the store's plan before applying
                store.pendingPlan = plan
                store.applyReorganizePlan()
                dismiss()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(selectedCount == 0)
        }
        .padding(16)
        .background(.regularMaterial)
    }

    private func setAll(_ value: Bool) {
        for idx in plan.moves.indices {
            plan.moves[idx].isSelected = value
        }
    }
}
