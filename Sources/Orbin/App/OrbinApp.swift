import AppKit
import SwiftUI

@main
struct AppLauncher {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst()).filter { !$0.hasPrefix("-psn_") }
        if args.contains("--cli") || args.contains("--organize") || args.contains("--help") || args.contains("-h") || args.contains("--apply") || args.contains("--dry-run") {
            await CLIHandler.run(arguments: args)
            exit(0)
        } else {
            OrbinApp.main()
        }
    }
}

struct OrbinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = OrganizerStore()

    var body: some Scene {
        WindowGroup("Orbin") {
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
