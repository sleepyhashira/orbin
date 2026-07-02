import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: OrganizerStore
    @State private var isCompact = false

    var body: some View {
        List(selection: $store.selection) {
            Section {
                sidebarItem(
                    title: "Overview",
                    systemImage: "chart.pie",
                    countText: "\(Formatters.count(store.summary.fileCount)) files",
                    helpText: "Overview – \(Formatters.count(store.summary.fileCount)) files"
                )
                .tag(SidebarSelection.overview)
            }

            Section(isCompact ? "" : "Groups") {
                ForEach(FileCategory.allCases) { category in
                    let count = store.summary.categories[category, default: 0]
                    sidebarItem(
                        title: category.rawValue,
                        systemImage: category.systemImage,
                        countText: "\(Formatters.count(count)) files",
                        helpText: "\(category.rawValue) – \(Formatters.count(count)) files"
                    )
                    .tag(SidebarSelection.category(category))
                }
            }

            Section(isCompact ? "" : "Insights") {
                sidebarItem(
                    title: "Large Files",
                    systemImage: "internaldrive",
                    countText: "\(Formatters.count(store.summary.largestFiles.count)) shown",
                    helpText: "Large Files – \(Formatters.count(store.summary.largestFiles.count)) shown"
                )
                .tag(SidebarSelection.largeFiles)

                sidebarItem(
                    title: "Duplicates",
                    systemImage: "doc.on.doc",
                    countText: "\(Formatters.count(store.duplicateGroups.count)) groups",
                    helpText: "Duplicates – \(Formatters.count(store.duplicateGroups.count)) groups"
                )
                .tag(SidebarSelection.duplicates)
            }

            // AI classification status row (non-selectable)
            if store.aiStatus != .idle {
                Section {
                    AIStatusBadge(aiStatus: store.aiStatus)
                        .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.sidebar)
        .overlay(
            GeometryReader { geo in
                Color.clear
                    .onAppear { isCompact = geo.size.width < 160 }
                    .onChange(of: geo.size.width) { newWidth in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isCompact = newWidth < 160
                        }
                    }
            }
        )
    }

    @ViewBuilder
    private func sidebarItem(title: String, systemImage: String, countText: String, helpText: String) -> some View {
        if isCompact {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(maxWidth: .infinity)
                .help(helpText)
        } else {
            Label(title, systemImage: systemImage)
                .badge(Text(countText))
                .help(helpText)
        }
    }
}
