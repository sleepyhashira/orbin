import SwiftUI

struct ContentView: View {
    @ObservedObject var store: OrganizerStore
    @StateObject private var thumbnails = ThumbnailProvider()
    @State private var showAISettings = false
    @AppStorage("appColorScheme") private var colorScheme: AppColorScheme = .dark

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // ── Sidebar (fixed width, no floating column) ──
                SidebarView(store: store)
                    .frame(width: 190)

                // ── Thin separator ──
                Rectangle()
                    .fill(Color.obsidianGlassBorder)
                    .frame(width: 1)

                // ── Main content ──
                DetailView(store: store, thumbnails: thumbnails)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.obsidianBackground)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Spacer()

                    Button {
                        store.chooseFolder()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("Open a folder to scan and organize.")

                    Button {
                        store.rescan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.rootURL == nil)
                    .help("Scan the selected folder again.")

                    if case .scanning = store.status {
                        Button {
                            store.cancelScan()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .help("Cancel the current folder scan.")
                    }

                    // ── AI Plan button ──
                    if store.planStatus.isGenerating {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text(store.planStatus.message)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            store.generateReorganizePlan()
                        } label: {
                            Image(systemName: "wand.and.stars")
                        }
                        .disabled(store.files.isEmpty || store.planStatus.isGenerating)
                        .help("Ask Qwen AI to suggest how to organize files.")
                    }

                    // AI status badge
                    AIStatusBadge(aiStatus: store.aiStatus)

                    Button {
                        showAISettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Configure AI classification.")
                }
            }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search files…")
        .sheet(isPresented: $showAISettings) {
            AISettingsView(store: store)
        }
        .sheet(item: $store.pendingPlan) { plan in
            AIPlanView(store: store, plan: plan)
        }
        .onChange(of: store.planStatus) { newStatus in
            if case .ready = newStatus {
                // pendingPlan is already set; the sheet binding opens automatically
            }
        }
        .preferredColorScheme(.dark)
    }
}
