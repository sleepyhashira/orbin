# CLAUDE.md — Orbin

## What is this project?

Orbin is a native macOS SwiftUI desktop app that scans a user-selected folder, classifies every file by type (Images, Documents, Audio, Video, Archives, Code, Applications, Other), and suggests an AI-powered reorganization plan. It uses a **local Qwen model via Ollama** — fully offline, no cloud APIs.

## Build & Run

```bash
# Full build + launch (handles Ollama, model pull, compile, app bundle)
./script/build_and_run.sh

# Quick compile-only (no Ollama, no app bundle)
swift build

# Run after swift build
.build/debug/Orbin
```

- Swift Package Manager, no Xcode project
- Minimum deployment: **macOS 13**
- Swift tools version: **5.9**

## Project Structure

```
Sources/Orbin/
├── App/                    # OrbinApp.swift — @main entry point
├── Models/                 # Data types (FileItem, FileCategory, FileMovePlan, AppColorScheme, SidebarSelection)
├── Services/               # Business logic (no UI)
│   ├── OllamaClassifier    # Actor — LLM API client (classify, suggest folder, ping)
│   ├── FileScanner         # Async recursive directory scanner
│   ├── DuplicateFinder     # SHA256-based duplicate detection
│   ├── FileOperationService# Move/trash file operations
│   └── ThumbnailProvider   # QuickLook thumbnail cache
├── Stores/                 # OrganizerStore — single @MainActor ObservableObject (source of truth)
├── Support/                # AppTheme (colors, fonts, button styles), Formatters, PlaceholderView
└── Views/                  # All SwiftUI views
    ├── ContentView         # Root NavigationSplitView + toolbar
    ├── SidebarView         # Category/Insights navigation (custom VStack, not List)
    ├── DetailView          # Header cards + action bar + file table
    ├── FileTableView       # SwiftUI Table with thumbnail cells
    ├── InspectorView       # File metadata + preview + Reveal in Finder
    ├── ChartView           # Canvas-based donut chart (no Charts framework for donut)
    ├── AIPlanView          # Sheet: review AI reorganization plan before applying
    └── AISettingsView      # Sheet: Ollama connection, model picker, AI status badge
```

## Architecture Patterns

- **Single store**: `OrganizerStore` is the sole `@ObservableObject`. All views observe it via `@ObservedObject`.
- **Actor for AI**: `OllamaClassifier` is a Swift actor (thread-safe singleton). It calls `http://localhost:11434/api/generate`.
- **No external dependencies**: Only Apple frameworks — SwiftUI, Charts (for palette only), UniformTypeIdentifiers.
- **Dual classification**: Files get a rule-based `category` (from `FileClassifier`) and an optional `aiCategory` (from Qwen). `effectiveCategory` = AI if available, else rule-based.

## Design System (Obsidian Amber)

All visual tokens are in `Support/AppTheme.swift`:

- **Colors**: `Color.obsidian*` — dark surfaces (#131315 base) with amber/orange accents (#ffb693, #ff7a2f)
- **Fonts**: System `.rounded` for UI text, `.monospaced` for code/data — NOT custom font files
- **Button styles**: `PrimaryButtonStyle` (amber gradient), `SecondaryButtonStyle` (glass border), `DestructiveButtonStyle` (red gradient), `CompactButtonStyle` (inline)
- **Spacing**: `AppSpacing.*` (unit=4, gutter=16, stackSm=8, stackMd=16)
- **Radii**: `AppCornerRadius.*` (sm=4, default=6, md=10, lg=14)

## Key Conventions

1. **All colors from theme** — never use raw `.red`, `.blue`, `.orange`, `.purple`. Use `Color.obsidian*` tokens.
2. **All fonts from theme** — use `.appBodyMedium()`, `.appHeadlineSmall()`, etc. or `Font.system(size:weight:design:)`. Never use `.headline`, `.caption` etc.
3. **Sidebar is custom** — uses `VStack` + `ScrollView` + manual `Button`s, NOT `List` with `.sidebar` style. This gives full control over selection highlight.
4. **File classification prompts** are in `OllamaClassifier.swift` lines ~220-265. They give Qwen an explicit extension→category lookup table for deterministic results.
5. **No sub-categorization** — files go into top-level category folders only (Images, Documents, Code, etc.).

## Common Tasks

| Task | Where to change |
|------|----------------|
| Add a new file category | `Models/FileCategory.swift` — add case, systemImage, sortOrder, chartColor |
| Change AI prompts | `Services/OllamaClassifier.swift` — `classifySingle()` and `suggestFolder()` |
| Adjust theme colors | `Support/AppTheme.swift` — `Color.obsidian*` statics |
| Add a button style | `Support/AppTheme.swift` — new `ButtonStyle` struct |
| Modify toolbar | `Views/ContentView.swift` — `.toolbar` block |
| Change header/stats cards | `Views/DetailView.swift` — `headerSection` and `statsCards` |
| Edit sidebar items | `Views/SidebarView.swift` — `sidebarRow()` calls |

## Testing

No unit tests yet. Verify changes by building:
```bash
swift build
```
