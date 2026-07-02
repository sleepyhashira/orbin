import SwiftUI

// MARK: - AI Settings Sheet

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: OrganizerStore

    @State private var isEnabled: Bool = OllamaSettings.isEnabled
    @State private var model: String = OllamaSettings.model
    @State private var baseURL: String = OllamaSettings.baseURL
    @State private var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus {
        case unknown, checking, online, offline
        var label: String {
            switch self {
            case .unknown:   return "Not checked"
            case .checking:  return "Checking…"
            case .online:    return "Ollama is running ✓"
            case .offline:   return "Ollama not detected"
            }
        }
        var color: Color {
            switch self {
            case .unknown, .checking: return .secondary
            case .online:             return .green
            case .offline:            return .red
            }
        }
    }

    private let presetModels = [
        "qwen2.5:1.5b",
        "qwen2.5:7b",
        "qwen2.5:14b",
        "qwen2.5:32b",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Classification")
                        .font(.headline)
                    Text("Powered by Qwen via Ollama (local, no internet required)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(20)
            .background(.regularMaterial)

            Divider()

            // Settings body
            Form {
                Section("Model") {
                    Picker("Qwen model", selection: $model) {
                        ForEach(presetModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .disabled(!isEnabled)

                    HStack {
                        Text("Custom model")
                            .foregroundStyle(isEnabled ? .primary : .tertiary)
                        TextField("e.g. qwen2.5:72b", text: $model)
                            .textFieldStyle(.roundedBorder)
                            .disabled(!isEnabled)
                    }
                }

                Section("Connection") {
                    HStack {
                        Text("Ollama URL")
                        TextField("http://localhost:11434", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .disabled(!isEnabled)
                    }

                    HStack(spacing: 10) {
                        Circle()
                            .fill(connectionStatus.color)
                            .frame(width: 8, height: 8)
                        Text(connectionStatus.label)
                            .foregroundStyle(connectionStatus.color)
                        Spacer()
                        Button("Test Connection") {
                            checkConnection()
                        }
                        .disabled(!isEnabled || connectionStatus == .checking)
                    }
                }

                Section("Actions") {
                    HStack {
                        Button("Re-classify Current Folder") {
                            saveSettings()
                            store.reclassifyWithAI()
                            dismiss()
                        }
                        .disabled(!isEnabled || store.files.isEmpty || store.aiStatus.isRunning)
                        .help("Run AI classification again on the currently scanned folder.")

                        if store.aiStatus.isRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    Text(store.aiStatus.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .disabled(!isEnabled)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)

            Divider()

            // Footer buttons
            HStack {
                Button("Install Ollama…") {
                    NSWorkspace.shared.open(URL(string: "https://ollama.com")!)
                }
                .buttonStyle(.link)

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(.regularMaterial)
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { checkConnection() }
    }

    // MARK: - Helpers

    private func saveSettings() {
        OllamaSettings.isEnabled = isEnabled
        OllamaSettings.model = model.trimmingCharacters(in: .whitespaces)
        OllamaSettings.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
        Task { await OllamaClassifier.shared.resetCache() }
    }

    private func checkConnection() {
        connectionStatus = .checking
        Task {
            // Temporarily use the URL field value for the check
            let savedURL = OllamaSettings.baseURL
            OllamaSettings.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
            await OllamaClassifier.shared.resetCache()
            let available = await OllamaClassifier.shared.isAvailable()
            OllamaSettings.baseURL = savedURL          // restore
            await MainActor.run {
                connectionStatus = available ? .online : .offline
            }
        }
    }
}

// MARK: - AI Status Bar (embedded in toolbars / sidebars)

struct AIStatusBadge: View {
    let aiStatus: OrganizerStore.AIStatus

    var body: some View {
        switch aiStatus {
        case .idle:
            EmptyView()
        case .unavailable:
            Label("AI offline", systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.orange)
                .help("Ollama is not running. AI classification is disabled.")
        case .classifying(let done, let total):
            HStack(spacing: 4) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .controlSize(.mini)
                Text("AI \(done)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .help("Qwen is classifying files…")
        case .completed(let n):
            Label("AI: \(n) updated", systemImage: "sparkles")
                .font(.caption2)
                .foregroundStyle(.purple)
                .help("AI classification updated \(n) file\(n == 1 ? "" : "s").")
        }
    }
}
