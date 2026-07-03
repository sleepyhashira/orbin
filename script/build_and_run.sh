#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Orbin"
BUNDLE_ID="com.local.Orbin"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_RESOURCES="$APP_CONTENTS/Resources"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

# ══════════════════════════════════════════════════════════════════════════════
# AI SETUP  –  Qwen via Ollama (local, no internet required at runtime)
# ══════════════════════════════════════════════════════════════════════════════

AI_CONFIG_FILE="$ROOT_DIR/.ai-config"

# Colour helpers (gracefully no-op if terminal doesn't support them)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

print_header() {
  echo ""
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}${BOLD}║   Orbin – AI Model Setup         ║${RESET}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
  echo ""
}

# ── Step 1: Install Ollama if missing ────────────────────────────────────────
setup_ollama() {
  if command -v ollama &>/dev/null; then
    echo -e "${GREEN}✅  Ollama already installed${RESET} ($(ollama --version 2>/dev/null || echo 'version unknown'))"
    return
  fi

  echo -e "${YELLOW}⚡  Ollama not found. Installing via Homebrew…${RESET}"
  if ! command -v brew &>/dev/null; then
    echo -e "${RED}❌  Homebrew is required but not installed.${RESET}"
    echo "    Install it from https://brew.sh then re-run this script."
    exit 1
  fi
  brew install ollama
  echo -e "${GREEN}✅  Ollama installed.${RESET}"
}

# ── Step 2: Interactive model selection ──────────────────────────────────────
select_model() {
  # If a config file already exists, read the previously chosen model
  if [[ -f "$AI_CONFIG_FILE" ]]; then
    SAVED_MODEL=$(grep '^OLLAMA_MODEL=' "$AI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || true)
  else
    SAVED_MODEL=""
  fi

  # If running in CLI mode or non-interactively, skip interactive prompt
  if [[ "$MODE" == -* || "$MODE" == "help" || ! -t 0 ]]; then
    SELECTED_MODEL="${SAVED_MODEL:-qwen2.5:1.5b}"
    return
  fi

  print_header

  echo -e "${BOLD}Choose a Qwen model for AI file classification:${RESET}"
  echo ""
  echo -e "  ${BOLD}1)${RESET} qwen2.5:1.5b  │ ~1 GB  │ ⚡ Very fast  │ ${GREEN}Recommended for 8 GB RAM${RESET}"
  echo -e "  ${BOLD}2)${RESET} qwen2.5:7b    │ ~4.7 GB│ 🔥 Fast       │ Good for 16 GB RAM"
  echo -e "  ${BOLD}3)${RESET} qwen2.5:14b   │ ~9 GB  │ 🐢 Moderate   │ Best quality, 32 GB RAM"
  echo -e "  ${BOLD}4)${RESET} qwen2.5:32b   │ ~20 GB │ 🐌 Slow       │ Maximum quality"
  echo -e "  ${BOLD}5)${RESET} Skip / Disable AI classification"
  echo ""

  if [[ -n "$SAVED_MODEL" ]]; then
    echo -e "  ${CYAN}(Previously selected: ${BOLD}$SAVED_MODEL${RESET}${CYAN})${RESET}"
    echo -e "  Press ${BOLD}Enter${RESET} to keep it, or choose a number to change."
    echo ""
  fi

  while true; do
    read -rp "  Enter choice [1-5]: " CHOICE
    # Default to saved model on empty input
    if [[ -z "$CHOICE" && -n "$SAVED_MODEL" ]]; then
      SELECTED_MODEL="$SAVED_MODEL"
      break
    fi
    case "$CHOICE" in
      1) SELECTED_MODEL="qwen2.5:1.5b"; break ;;
      2) SELECTED_MODEL="qwen2.5:7b";   break ;;
      3) SELECTED_MODEL="qwen2.5:14b";  break ;;
      4) SELECTED_MODEL="qwen2.5:32b";  break ;;
      5) SELECTED_MODEL="none";         break ;;
      *) echo -e "  ${RED}Invalid choice. Please enter 1–5.${RESET}" ;;
    esac
  done
}

# ── Step 3: Pull the model if needed ─────────────────────────────────────────
pull_model_if_needed() {
  local model="$1"

  if [[ "$model" == "none" ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  AI classification disabled.${RESET} You can re-enable it by re-running this script."
    # Write config with AI disabled
    printf 'OLLAMA_MODEL=none\nAI_ENABLED=false\n' > "$AI_CONFIG_FILE"
    return
  fi

  # Check if model is already pulled
  if ollama list 2>/dev/null | grep -q "^${model}"; then
    echo -e "${GREEN}✅  ${model} already downloaded.${RESET}"
  else
    echo ""
    echo -e "${CYAN}📥  Pulling ${BOLD}${model}${RESET}${CYAN} from Ollama registry…${RESET}"
    echo -e "    This is a one-time download. Grab a coffee ☕"
    echo ""
    ollama pull "$model"
    echo ""
    echo -e "${GREEN}✅  ${model} downloaded successfully.${RESET}"
  fi

  # Write config so the Swift app reads the chosen model on first launch
  printf 'OLLAMA_MODEL=%s\nAI_ENABLED=true\n' "$model" > "$AI_CONFIG_FILE"
  echo -e "    Config saved to ${CYAN}.ai-config${RESET}"
}

# ── Step 4: Ensure Ollama server is running ───────────────────────────────────
start_ollama_server() {
  if [[ "${SELECTED_MODEL}" == "none" ]]; then return; fi

  if curl -sf --max-time 2 http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✅  Ollama server already running.${RESET}"
  else
    echo -e "${CYAN}🚀  Starting Ollama server in the background…${RESET}"
    ollama serve > /tmp/ollama.log 2>&1 &
    OLLAMA_PID=$!
    # Wait up to 8s for it to become ready
    for i in {1..8}; do
      sleep 1
      if curl -sf --max-time 1 http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}✅  Ollama server ready (PID $OLLAMA_PID).${RESET}"
        return
      fi
    done
    echo -e "${YELLOW}⚠️  Ollama server started but not yet responding — it may still be warming up.${RESET}"
  fi
}

# ── Run the AI setup flow ─────────────────────────────────────────────────────
setup_ollama
select_model
echo ""
pull_model_if_needed "$SELECTED_MODEL"
echo ""
start_ollama_server
echo ""

# ══════════════════════════════════════════════════════════════════════════════

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

# Generate and copy AppIcon if assets/organizer.png exists
if [[ -f "$ROOT_DIR/assets/organizer.png" ]]; then
  echo "Generating AppIcon..."
  ICONSET_DIR="/tmp/$APP_NAME.iconset"
  mkdir -p "$ICONSET_DIR"
  sips -z 256 256 "$ROOT_DIR/assets/organizer.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ROOT_DIR/assets/organizer.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  iconutil -c icns "$ICONSET_DIR" -o "$APP_RESOURCES/AppIcon.icns"
  rm -rf "$ICONSET_DIR"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --cli|--organize|--help|-h)
    "$APP_BINARY" "$@"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    # If mode starts with - or is a directory path, try running CLI mode directly
    if [[ "$MODE" == -* || -d "$MODE" ]]; then
      "$APP_BINARY" "$@"
    else
      echo "usage: $0 [run|--cli|--debug|--logs|--telemetry|--verify]" >&2
      exit 2
    fi
    ;;
esac
