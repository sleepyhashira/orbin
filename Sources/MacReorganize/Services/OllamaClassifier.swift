import Foundation

// MARK: - Settings Keys

enum OllamaSettings {
    static let enabledKey = "ai.ollama.enabled"
    static let modelKey   = "ai.ollama.model"
    static let baseURLKey = "ai.ollama.baseURL"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var model: String {
        get { UserDefaults.standard.string(forKey: modelKey) ?? "qwen2.5:1.5b" }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }

    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: baseURLKey) ?? "http://localhost:11434" }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    /// Called once at app launch to apply settings from the `.ai-config` file
    /// written by `build_and_run.sh`. Only writes to UserDefaults if the user
    /// hasn't already configured the app manually (i.e. first launch).
    static func applyBuildConfig() {
        // Only auto-apply on first launch (no model key set yet)
        guard UserDefaults.standard.string(forKey: modelKey) == nil else { return }

        guard let configURL = findConfigFile() else { return }
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else { return }

        var configModel: String?
        var configEnabled: Bool?

        for line in contents.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "=")
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "OLLAMA_MODEL":
                configModel = value
            case "AI_ENABLED":
                configEnabled = (value.lowercased() == "true")
            default:
                break
            }
        }

        if let enabled = configEnabled {
            UserDefaults.standard.set(enabled, forKey: enabledKey)
        }
        if let model = configModel, model != "none", !model.isEmpty {
            UserDefaults.standard.set(model, forKey: modelKey)
        }
    }

    /// Walk up from the app bundle to find the `.ai-config` file in the project root.
    private static func findConfigFile() -> URL? {
        // In development: bundle is at <root>/dist/MacReorganize.app
        // Config is at   <root>/.ai-config
        var dir = Bundle.main.bundleURL
        for _ in 0..<4 {
            dir = dir.deletingLastPathComponent()
            let candidate = dir.appendingPathComponent(".ai-config")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}

// MARK: - Ollama Wire Types

private struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool = false
    let options: OllamaOptions
}

private struct OllamaOptions: Encodable {
    let temperature: Double = 0.0
    let num_predict: Int       // caller sets this
    init(numPredict: Int = 16) { num_predict = numPredict }
}

private struct OllamaGenerateResponse: Decodable {
    let response: String
}

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaModel]
    struct OllamaModel: Decodable { let name: String }
}

// MARK: - OllamaClassifier

/// Thread-safe actor that classifies files using a locally running Qwen model via Ollama.
/// Falls back gracefully if Ollama is not running.
actor OllamaClassifier {

    // MARK: Singleton

    static let shared = OllamaClassifier()
    private init() {}

    // MARK: State

    /// Cached availability; reset when settings change.
    private var _availabilityCache: Bool?

    // MARK: - Public API

    /// Check if Ollama is reachable. Cached for the lifetime of a scan.
    func isAvailable() async -> Bool {
        if let cached = _availabilityCache { return cached }
        let result = await pingOllama()
        _availabilityCache = result
        return result
    }

    /// Invalidate the availability cache (call when settings change or a new scan starts).
    func resetCache() {
        _availabilityCache = nil
    }

    /// Classify a batch of files concurrently.
    /// Returns a dictionary mapping `FileItem.id` → `FileCategory`.
    /// Calls `progress` on the calling actor (not main thread) with each completed count.
    func classifyBatch(
        _ files: [FileItem],
        progress: @escaping @Sendable (Int) -> Void
    ) async -> [String: FileCategory] {
        guard OllamaSettings.isEnabled, await isAvailable() else { return [:] }

        var results: [String: FileCategory] = [:]
        var completed = 0

        await withTaskGroup(of: (String, FileCategory?).self) { group in
            for file in files {
                group.addTask {
                    let category = try? await self.classifySingle(file: file)
                    return (file.id, category)
                }
            }

            for await (id, category) in group {
                if let category {
                    results[id] = category
                }
                completed += 1
                if completed.isMultiple(of: 10) || completed == files.count {
                    progress(completed)
                }
            }
        }

        return results
    }

    // MARK: - Reorganization Plan

    /// Ask Qwen to suggest a destination folder for every file, then build a
    /// `ReorganizePlan` the user can review before anything is moved.
    func suggestFolderPlan(
        files: [FileItem],
        rootURL: URL,
        progress: @escaping @Sendable (Int) -> Void
    ) async -> ReorganizePlan? {
        guard OllamaSettings.isEnabled, await isAvailable() else { return nil }

        var moves: [FileMovePlan] = []
        var completed = 0
        let fm = FileManager.default

        await withTaskGroup(of: FileMovePlan?.self) { group in
            for file in files {
                group.addTask {
                    let folder = (try? await self.suggestFolder(for: file)) ?? file.effectiveCategory.rawValue
                    let clean = Self.sanitiseFolder(folder)
                    let destDir = rootURL.appendingPathComponent(clean, isDirectory: true)
                    let exists = fm.fileExists(atPath: destDir.path)

                    // Skip files already in their suggested folder
                    let alreadyThere = file.url.deletingLastPathComponent()
                        .standardizedFileURL == destDir.standardizedFileURL
                    guard !alreadyThere else { return nil }

                    return FileMovePlan(
                        id: UUID(),
                        file: file,
                        suggestedFolder: clean,
                        destinationURL: destDir,
                        folderExists: exists
                    )
                }
            }

            for await result in group {
                if let plan = result { moves.append(plan) }
                completed += 1
                if completed.isMultiple(of: 5) || completed == files.count {
                    progress(completed)
                }
            }
        }

        guard !moves.isEmpty else { return nil }
        moves.sort { $0.suggestedFolder < $1.suggestedFolder }
        return ReorganizePlan(moves: moves)
    }

    // MARK: - Internal

    /// Classify a file into a category based on its extension/type.
    /// The prompt gives Qwen a clear extension→category mapping table so
    /// it doesn't have to guess — just match the file extension.
    private func classifySingle(file: FileItem) async throws -> FileCategory {
        let prompt = """
        Classify this file into exactly one category based on its extension. \
        Use these rules:
        - Images: png, jpg, jpeg, gif, bmp, svg, webp, tiff, ico, heic, raw
        - Documents: pdf, doc, docx, txt, rtf, odt, xls, xlsx, csv, ppt, pptx, pages, numbers, key, md
        - Audio: mp3, wav, aac, flac, ogg, m4a, wma, aiff
        - Video: mp4, mov, avi, mkv, wmv, flv, webm, m4v, mpg, mpeg
        - Archives: zip, tar, gz, bz2, xz, 7z, rar, dmg, iso
        - Code: swift, js, ts, tsx, jsx, py, rb, go, rs, java, c, cpp, h, html, css, scss, json, yaml, yml, toml, xml, sh, sql
        - Applications: app, exe, msi, pkg, deb, rpm
        - Other: anything not listed above

        File: "\(file.name)"

        Reply with only the category name, nothing else.
        """

        let response = try await generate(prompt: prompt, numPredict: 16, retries: 3)
        return FileClassifier.fromAIResponse(response) ?? file.category
    }

    /// Suggest a folder name for the file. We want simple category-level grouping
    /// (e.g. "Images", "Documents", "Code") — no sub-folders or creative names.
    private func suggestFolder(for file: FileItem) async throws -> String {
        let prompt = """
        You are a file organizer. Based on the file extension, return the \
        category folder name where this file belongs.
        Use only these folder names:
        - Images (for png, jpg, jpeg, gif, svg, webp, heic, bmp, tiff, ico, raw)
        - Documents (for pdf, doc, docx, txt, rtf, xls, xlsx, csv, ppt, pptx, pages, numbers, key, md)
        - Audio (for mp3, wav, aac, flac, ogg, m4a, wma, aiff)
        - Video (for mp4, mov, avi, mkv, wmv, flv, webm, m4v)
        - Archives (for zip, tar, gz, 7z, rar, dmg, iso)
        - Code (for swift, js, ts, py, go, rs, java, c, cpp, html, css, json, yaml, sh, sql)
        - Applications (for app, exe, pkg, dmg)
        - Other (for anything not listed)

        File: "\(file.name)"

        Reply with only the folder name, nothing else.
        """
        let raw = try await generate(prompt: prompt, numPredict: 16, retries: 3)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sanitise an LLM-produced folder name so it is safe to use as a directory name.
    private static func sanitiseFolder(_ raw: String) -> String {
        var s = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove surrounding quotes the model sometimes adds
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
            // Replace slashes/backslashes with a dash
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        // Collapse multiple spaces
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        // Hard cap at 40 chars
        if s.count > 40 { s = String(s.prefix(40)).trimmingCharacters(in: .whitespaces) }
        return s.isEmpty ? "Other" : s
    }

    /// Call Ollama /api/generate with exponential-backoff retries.
    private func generate(prompt: String, numPredict: Int = 16, retries: Int) async throws -> String {
        let baseURLString = OllamaSettings.baseURL
        let model = OllamaSettings.model

        guard let url = URL(string: "\(baseURLString)/api/generate") else {
            throw OllamaError.invalidURL
        }

        let body = OllamaGenerateRequest(model: model, prompt: prompt, options: OllamaOptions(numPredict: numPredict))
        let encoded = try JSONEncoder().encode(body)

        var lastError: Error = OllamaError.maxRetriesExceeded
        var delay: UInt64 = 500_000_000 // 0.5s

        for attempt in 0..<retries {
            do {
                var request = URLRequest(url: url, timeoutInterval: 30)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = encoded

                let (data, httpResponse) = try await URLSession.shared.data(for: request)

                guard let http = httpResponse as? HTTPURLResponse, http.statusCode == 200 else {
                    throw OllamaError.httpError((httpResponse as? HTTPURLResponse)?.statusCode ?? -1)
                }

                let decoded = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
                return decoded.response
            } catch {
                lastError = error
                if attempt < retries - 1 {
                    try? await Task.sleep(nanoseconds: delay)
                    delay *= 2
                }
            }
        }

        throw lastError
    }

    /// Ping /api/tags to check if Ollama is running.
    private func pingOllama() async -> Bool {
        let baseURLString = OllamaSettings.baseURL
        guard let url = URL(string: "\(baseURLString)/api/tags") else { return false }

        var request = URLRequest(url: url, timeoutInterval: 3)
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case maxRetriesExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid Ollama URL in settings."
        case .httpError(let code):  return "Ollama returned HTTP \(code)."
        case .maxRetriesExceeded:   return "Ollama did not respond after several retries."
        }
    }
}
