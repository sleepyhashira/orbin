import SwiftUI

struct ContentView: View {
    @ObservedObject var store: OrganizerStore
    @StateObject private var thumbnails = ThumbnailProvider()
    @State private var showAISettings = false
    @AppStorage("appColorScheme") private var colorScheme: AppColorScheme = .system

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 60, ideal: 260, max: 320)
        } detail: {
            DetailView(store: store, thumbnails: thumbnails)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.chooseFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Open a folder to scan and organize.")

                Button {
                    store.rescan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(store.rootURL == nil)
                .help("Scan the selected folder again.")

                if case .scanning = store.status {
                    Button {
                        store.cancelScan()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .help("Cancel the current folder scan.")
                }

                Divider()

                // ── AI Plan button ────────────────────────────────────────
                if store.planStatus.isGenerating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(store.planStatus.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        store.generateReorganizePlan()
                    } label: {
                        Label("Suggest AI Plan", systemImage: "wand.and.stars")
                    }
                    .disabled(store.files.isEmpty || store.planStatus.isGenerating)
                    .help("Ask Qwen AI to suggest how to organize files into folders.")
                }

                // AI classification status badge
                AIStatusBadge(aiStatus: store.aiStatus)
                    .padding(.horizontal, 2)

                Button {
                    showAISettings = true
                } label: {
                    Label("AI Settings", systemImage: "sparkles")
                }
                .help("Configure AI classification using local Qwen model.")

                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Toggle("", isOn: Binding(
                        get: { colorScheme == .dark },
                        set: { isDark in colorScheme = isDark ? .dark : .light }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    
                    Image(systemName: "moon.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .help("Toggle Dark Mode")
            }
        }
        .sheet(isPresented: $showAISettings) {
            AISettingsView(store: store)
        }
        .sheet(item: $store.pendingPlan) { plan in
            AIPlanView(store: store, plan: plan)
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search files")
        // Auto-open the plan sheet when the plan becomes ready
        .onChange(of: store.planStatus) { newStatus in
            if case .ready = newStatus {
                // pendingPlan is already set; the sheet binding opens automatically
            }
        }
        .preferredColorScheme(colorScheme.colorScheme)
    }
}
