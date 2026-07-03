import AppKit
import Foundation

@MainActor
final class OrganizerStore: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var files: [FileItem] = []
    @Published private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published private(set) var summary: ScanSummary = .empty
    @Published var selectedFile: FileItem?
    @Published var selection: SidebarSelection = .overview
    @Published var searchText = ""
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastOperationLog: [String] = []

    // AI classification state
    @Published private(set) var aiStatus: AIStatus = .idle

    // AI reorganization plan state
    @Published var pendingPlan: ReorganizePlan? = nil
    @Published private(set) var planStatus: PlanStatus = .idle

    enum PlanStatus: Equatable {
        case idle
        case generating(Int, Int)  // (done, total)
        case ready
        case applying
        case failed(String)

        var isGenerating: Bool {
            if case .generating = self { return true }
            return false
        }
        var message: String {
            switch self {
            case .idle:                        return ""
            case .generating(let d, let t):   return "Building plan… \(d)/\(t)"
            case .ready:                       return "Plan ready – review before applying"
            case .applying:                    return "Applying moves…"
            case .failed(let m):               return m
            }
        }
    }

    enum AIStatus: Equatable {
        case idle
        case unavailable          // Ollama not running
        case classifying(Int, Int) // (done, total)
        case completed(Int)       // count updated by AI

        var message: String {
            switch self {
            case .idle:                         return ""
            case .unavailable:                  return "Ollama not detected – AI classification disabled"
            case .classifying(let d, let t):    return "AI classifying… \(d)/\(t)"
            case .completed(let n):             return "AI updated \(n) file\(n == 1 ? "" : "s")"
            }
        }

        var isRunning: Bool {
            if case .classifying = self { return true }
            return false
        }
    }

    private let scanner = FileScanner()
    private let duplicateFinder = DuplicateFinder()
    private let operationService = FileOperationService()
    private var scanTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private var planTask: Task<Void, Never>?

    enum Status: Equatable {
        case idle
        case scanning(Int)
        case findingDuplicates
        case failed(String)
        case completed(Date)


        var message: String {
            switch self {
            case .idle:
                return "Choose a folder to begin."
            case .scanning(let count):
                return "Scanning \(count) files..."
            case .findingDuplicates:
                return "Finding exact duplicates..."
            case .failed(let message):
                return message
            case .completed(let date):
                return "Last scan \(date.formatted(date: .omitted, time: .shortened))"
            }
        }
    }

    var filteredFiles: [FileItem] {
        let scoped: [FileItem]
        switch selection {
        case .overview:
            scoped = files
        case .category(let category):
            // Use effectiveCategory so AI overrides are reflected in the sidebar filter
            scoped = files.filter { $0.effectiveCategory == category }
        case .largeFiles:
            scoped = summary.largestFiles
        case .duplicates:
            scoped = duplicateGroups.flatMap(\.files)
        }

        guard !searchText.isEmpty else { return scoped }
        return scoped.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.relativePath.localizedCaseInsensitiveContains(searchText)
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        panel.message = "Choose a folder to visually organize."

        if panel.runModal() == .OK, let url = panel.url {
            rootURL = url
            scan(url)
        }
    }

    func rescan() {
        guard let rootURL else { return }
        scan(rootURL)
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        aiTask?.cancel()
        aiTask = nil
        status = .idle
        aiStatus = .idle
    }

    /// Manually trigger a fresh AI classification pass on the current file list.
    func reclassifyWithAI() {
        guard !files.isEmpty else { return }
        startAIClassification(for: files)
    }

    // MARK: - Reorganization Plan

    /// Ask Qwen to suggest a folder for every visible file and build a reviewable plan.
    func generateReorganizePlan() {
        guard let rootURL, !files.isEmpty else { return }
        planTask?.cancel()
        pendingPlan = nil
        let total = files.count
        planStatus = .generating(0, total)

        planTask = Task { [weak self] in
            guard let self else { return }
            let plan = await OllamaClassifier.shared.suggestFolderPlan(
                files: self.files,
                rootURL: rootURL
            ) { done in
                Task { @MainActor in
                    self.planStatus = .generating(done, total)
                }
            }
            await MainActor.run {
                if let plan {
                    self.pendingPlan = plan
                    self.planStatus = .ready
                } else {
                    self.planStatus = .failed("Ollama unavailable or no moves suggested.")
                }
            }
        }
    }

    /// Apply the selected moves in the pending plan, then rescan.
    func applyReorganizePlan() {
        guard let rootURL, let plan = pendingPlan else { return }
        let selectedMoves = plan.selectedMoves
        guard !selectedMoves.isEmpty else {
            pendingPlan = nil
            planStatus = .idle
            return
        }
        planStatus = .applying
        do {
            // Create missing folders
            for dir in plan.foldersToCreate {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            // Move files
            var log: [String] = []
            for move in selectedMoves {
                let target = operationService.uniqueDestination(
                    for: move.file.url.lastPathComponent, in: move.destinationURL)
                try FileManager.default.moveItem(at: move.file.url, to: target)
                log.append("\(move.file.name) → \(move.suggestedFolder)")
            }
            lastOperationLog = log
            pendingPlan = nil
            planStatus = .idle
            scan(rootURL)
        } catch {
            planStatus = .failed("Move failed: \(error.localizedDescription)")
        }
    }

    /// Discard the pending plan without moving anything.
    func discardReorganizePlan() {
        planTask?.cancel()
        planTask = nil
        pendingPlan = nil
        planStatus = .idle
    }

    func revealInFinder(_ file: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func moveSelectedFilesToNewFolder(named folderName: String) {
        guard let rootURL, !filteredFiles.isEmpty else { return }
        let cleanedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }

        let destination = rootURL.appendingPathComponent(cleanedName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            lastOperationLog = try operationService.move(filteredFiles, to: destination)
            scan(rootURL)
        } catch {
            status = .failed("Move failed: \(error.localizedDescription)")
        }
    }

    func trashDuplicateCopies() {
        let copies = duplicateGroups.flatMap { group in
            Array(group.files.dropFirst())
        }
        guard !copies.isEmpty else { return }

        do {
            lastOperationLog = try operationService.trash(copies)
            rescan()
        } catch {
            status = .failed("Trash failed: \(error.localizedDescription)")
        }
    }

    private func scan(_ url: URL) {
        scanTask?.cancel()
        aiTask?.cancel()
        files = []
        duplicateGroups = []
        summary = .empty
        selectedFile = nil
        lastOperationLog = []
        status = .scanning(0)
        aiStatus = .idle

        // Reset OllamaClassifier availability cache for this new scan
        Task { await OllamaClassifier.shared.resetCache() }

        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let scannedFiles = try await scanner.scan(rootURL: url) { count in
                    Task { @MainActor in
                        self.status = .scanning(count)
                    }
                }

                self.files = scannedFiles
                self.summary = Self.makeSummary(files: scannedFiles)
                self.status = .findingDuplicates
                self.duplicateGroups = await duplicateFinder.findDuplicates(in: scannedFiles)
                self.status = .completed(Date())

                // Kick off AI classification after the scan finishes
                self.startAIClassification(for: scannedFiles)
            } catch is CancellationError {
                self.status = .idle
            } catch {
                self.status = .failed("Scan failed: \(error.localizedDescription)")
            }
        }
    }

    private func startAIClassification(for filesToClassify: [FileItem]) {
        guard OllamaSettings.isEnabled else { return }
        aiTask?.cancel()

        let total = filesToClassify.count
        aiStatus = .classifying(0, total)

        aiTask = Task { [weak self] in
            guard let self else { return }

            // Check availability first
            let available = await OllamaClassifier.shared.isAvailable()
            guard available else {
                await MainActor.run { self.aiStatus = .unavailable }
                return
            }

            let results = await OllamaClassifier.shared.classifyBatch(filesToClassify) { done in
                Task { @MainActor in
                    self.aiStatus = .classifying(done, total)
                }
            }

            await MainActor.run {
                self.applyAICategories(results)
            }
        }
    }

    /// Merge AI-predicted categories back into the files array and update summary.
    private func applyAICategories(_ results: [String: FileCategory]) {
        guard !results.isEmpty else {
            aiStatus = .completed(0)
            return
        }

        var updated = 0
        for index in files.indices {
            if let aiCat = results[files[index].id] {
                files[index].aiCategory = aiCat
                updated += 1
            }
        }

        // Rebuild summary using effectiveCategory
        summary = Self.makeSummary(files: files)
        summary.aiClassifiedCount = updated
        aiStatus = .completed(updated)
    }

    private static func makeSummary(files: [FileItem]) -> ScanSummary {
        let totalSize = files.reduce(Int64(0)) { $0 + $1.size }
        // Use effectiveCategory so sidebar counts reflect AI overrides
        let categories = Dictionary(grouping: files, by: \.effectiveCategory).mapValues(\.count)
        let largestFiles = files.sorted { $0.size > $1.size }.prefix(40)

        return ScanSummary(
            totalSize: totalSize,
            fileCount: files.count,
            categories: categories,
            largestFiles: Array(largestFiles)
        )
    }
}
