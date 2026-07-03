import Foundation

struct CLIHandler {
    static func run(arguments: [String]) async {
        if arguments.contains("--help") || arguments.contains("-h") {
            printHelp()
            return
        }

        // Find folder argument
        var targetPath: String?
        var autoApply = false
        var useAI = true

        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            switch arg {
            case "--cli", "--organize":
                if i + 1 < arguments.count && !arguments[i + 1].hasPrefix("-") {
                    targetPath = arguments[i + 1]
                    i += 1
                }
            case "--apply", "-y":
                autoApply = true
            case "--dry-run":
                autoApply = false
            case "--ai":
                useAI = true
            case "--no-ai":
                useAI = false
            default:
                if !arg.hasPrefix("-") && targetPath == nil {
                    targetPath = arg
                }
            }
            i += 1
        }

        guard let pathString = targetPath else {
            print("❌ Error: No target directory specified.\n")
            printHelp()
            return
        }

        let rootURL = URL(fileURLWithPath: (pathString as NSString).expandingTildeInPath).standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDir), isDir.boolValue else {
            print("❌ Error: Directory does not exist at path: \(rootURL.path)")
            return
        }

        print("\n📂 Orbin CLI – Scanning directory: \(rootURL.path)")
        print("─────────────────────────────────────────────────────────────────")

        let scanner = FileScanner()
        let files: [FileItem]
        do {
            files = try await scanner.scan(rootURL: rootURL) { count in
                print("\r🔍 Scanned \(count) files...", terminator: "")
                fflush(stdout)
            }
            print("\r✅ Scanned \(files.count) regular files.                ")
        } catch {
            print("\n❌ Failed to scan directory: \(error.localizedDescription)")
            return
        }

        guard !files.isEmpty else {
            print("ℹ️ Directory is empty or contains no regular files.")
            return
        }

        // Generate Plan
        print("🤖 Generating reorganization plan (Mode: \(useAI ? "AI / Qwen" : "Rule-based"))...")
        let moves: [FileMovePlan]

        if useAI {
            OllamaSettings.applyBuildConfig()
            let aiAvailable = await OllamaClassifier.shared.isAvailable()
            if aiAvailable && OllamaSettings.isEnabled {
                let plan = await OllamaClassifier.shared.suggestFolderPlan(files: files, rootURL: rootURL) { completed in
                    print("\r✨ AI classified \(completed)/\(files.count) files...", terminator: "")
                    fflush(stdout)
                }
                print("")
                moves = plan?.moves ?? []
            } else {
                print("⚠️ Ollama AI server is offline or disabled. Falling back to rule-based folders.")
                moves = buildRuleBasedMoves(files: files, rootURL: rootURL)
            }
        } else {
            moves = buildRuleBasedMoves(files: files, rootURL: rootURL)
        }

        guard !moves.isEmpty else {
            print("✅ All files are already organized into their suggested folders!")
            return
        }

        // Display Plan
        print("\n📋 Proposed Reorganization Plan (\(moves.count) files to move):")
        print("─────────────────────────────────────────────────────────────────")
        let grouped = Dictionary(grouping: moves, by: \.suggestedFolder)
            .sorted { $0.key < $1.key }

        for (folder, folderMoves) in grouped {
            print("📁 \(folder)/ (\(folderMoves.count) files)")
            for move in folderMoves.prefix(5) {
                print("   ├── \(move.file.name)")
            }
            if folderMoves.count > 5 {
                print("   └── ... and \(folderMoves.count - 5) more")
            }
        }
        print("─────────────────────────────────────────────────────────────────")

        // Execution
        if !autoApply {
            print("\n💡 This was a dry run. To execute these moves, re-run with --apply or -y:")
            print("   Orbin --cli \"\(rootURL.path)\" --apply")
            return
        }

        print("\n🚀 Applying changes...")
        let fm = FileManager.default
        let opService = FileOperationService()
        var movedCount = 0

        for move in moves {
            do {
                if !fm.fileExists(atPath: move.destinationURL.path) {
                    try fm.createDirectory(at: move.destinationURL, withIntermediateDirectories: true)
                }
                let target = opService.uniqueDestination(for: move.file.name, in: move.destinationURL)
                try fm.moveItem(at: move.file.url, to: target)
                movedCount += 1
            } catch {
                print("⚠️ Failed to move \(move.file.name): \(error.localizedDescription)")
            }
        }

        print("🎉 Successfully moved \(movedCount) files!")
    }

    private static func buildRuleBasedMoves(files: [FileItem], rootURL: URL) -> [FileMovePlan] {
        var moves: [FileMovePlan] = []
        let fm = FileManager.default

        for file in files {
            let folder = file.effectiveCategory.rawValue
            let destDir = rootURL.appendingPathComponent(folder, isDirectory: true)
            let alreadyThere = file.url.deletingLastPathComponent().standardizedFileURL == destDir.standardizedFileURL
            if !alreadyThere {
                let exists = fm.fileExists(atPath: destDir.path)
                moves.append(FileMovePlan(
                    id: UUID(),
                    file: file,
                    suggestedFolder: folder,
                    destinationURL: destDir,
                    folderExists: exists
                ))
            }
        }
        moves.sort { $0.suggestedFolder < $1.suggestedFolder }
        return moves
    }

    private static func printHelp() {
        print("""
        Orbin CLI – AI-Powered Folder Organizer

        USAGE:
            Orbin --cli <directory> [options]

        OPTIONS:
            --cli <directory>   Run in headless CLI mode on the specified folder
            --apply, -y         Automatically execute the proposed file moves without confirmation
            --dry-run           Show proposed moves without modifying files (default if --apply not passed)
            --ai                Use local Qwen/Ollama model for folder suggestions (default)
            --no-ai             Use instant rule-based category folders (Images, Documents, Code, etc.)
            --help, -h          Display this help message

        EXAMPLES:
            Orbin --cli ~/Downloads --dry-run
            Orbin --cli ~/Downloads --apply --no-ai
        """)
    }
}
