import SwiftUI

struct ContentView: View {
    @ObservedObject var store: OrganizerStore
    @StateObject private var thumbnails = ThumbnailProvider()
    @State private var showAISettings = false
    @AppStorage("appColorScheme") private var colorScheme: AppColorScheme = .system

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
        } detail: {
            DetailView(store: store, thumbnails: thumbnails)
        }
        .background(Color.obsidianBackground)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Spacer()

                // ── Search ──
                // (handled by .searchable below)

                // ── Toolbar icons ──
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
        .sheet(isPresented: $showAISettings) {
            AISettingsView(store: store)
        }
        .sheet(item: $store.pendingPlan) { plan in
            AIPlanView(store: store, plan: plan)
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search files…")
        .onChange(of: store.planStatus) { newStatus in
            if case .ready = newStatus {
                // pendingPlan is already set; the sheet binding opens automatically
            }
        }
        .preferredColorScheme(colorScheme.colorScheme)
    }
}
