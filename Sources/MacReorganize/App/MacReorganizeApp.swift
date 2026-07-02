import AppKit
import SwiftUI

@main
struct MacReorganizeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = OrganizerStore()

    var body: some Scene {
        WindowGroup("Mac Reorganize") {
            ContentView(store: store)
                .frame(minWidth: 1040, minHeight: 680)
                .tint(.appAccent)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    store.chooseFolder()
                }
                .keyboardShortcut("o")

                Button("Rescan") {
                    store.rescan()
                }
                .keyboardShortcut("r")
                .disabled(store.rootURL == nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Apply model selected during build_and_run.sh (first launch only)
        OllamaSettings.applyBuildConfig()
    }
}
