import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: OrganizerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App title
            Text("Mac Reorganize")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Groups ──
                    sectionHeader("GROUPS")

                    sidebarRow(
                        title: "Overview",
                        systemImage: "chart.pie",
                        tag: .overview
                    )

                    ForEach(FileCategory.allCases) { category in
                        sidebarRow(
                            title: category.rawValue,
                            systemImage: category.systemImage,
                            tag: .category(category)
                        )
                    }

                    Spacer().frame(height: 20)

                    // ── Insights ──
                    sectionHeader("INSIGHTS")

                    sidebarRow(
                        title: "Large Files",
                        systemImage: "internaldrive",
                        tag: .largeFiles
                    )

                    sidebarRow(
                        title: "Duplicates",
                        systemImage: "doc.on.doc",
                        tag: .duplicates
                    )

                    // AI status (non-selectable)
                    if store.aiStatus != .idle {
                        Spacer().frame(height: 6)
                        AIStatusBadge(aiStatus: store.aiStatus)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.obsidianSurfaceContainerLow)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.obsidianOutline)
            .tracking(0.8)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }

    // MARK: - Sidebar Row

    private func sidebarRow(title: String, systemImage: String, tag: SidebarSelection) -> some View {
        let isSelected = store.selection == tag

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                store.selection = tag
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isSelected ? Color.obsidianPrimaryContainer : Color.obsidianSecondary)
                    .frame(width: 18, alignment: .center)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color.obsidianOnSurface)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.obsidianPrimaryContainer.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.obsidianPrimaryContainer.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }
}
