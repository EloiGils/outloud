#!/bin/bash
# aloud installer — free, local text-to-speech for macOS
# Usage: ./install.sh          (from a cloned repo)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ALOUD_HOME="$HOME/.aloud"
VENV="$ALOUD_HOME/venv"
BIN_DIR="/opt/homebrew/bin"
[ -d "$BIN_DIR" ] || BIN_DIR="/usr/local/bin"
PLIST="$HOME/Library/LaunchAgents/com.aloud.daemon.plist"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }

bold "aloud installer"
echo

# --- prerequisites ---------------------------------------------------------

if [ "$(uname)" != "Darwin" ]; then
  echo "aloud only supports macOS." >&2; exit 1
fi

if ! command -v brew >/dev/null; then
  echo "Homebrew is required (https://brew.sh). Install it and re-run." >&2; exit 1
fi

for pkg in mpv hammerspoon; do
  if ! brew list "$pkg" >/dev/null 2>&1 && ! command -v "$pkg" >/dev/null 2>&1 \
     && [ ! -d "/Applications/Hammerspoon.app" -o "$pkg" != "hammerspoon" ]; then
    bold "→ installing $pkg"
    if [ "$pkg" = "hammerspoon" ]; then brew install --cask hammerspoon; else brew install "$pkg"; fi
  fi
done

# --- python environment ----------------------------------------------------

bold "→ creating Python environment (~/.aloud/venv)"
mkdir -p "$ALOUD_HOME"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
bold "→ installing Kokoro TTS (this downloads PyTorch; a few minutes the first time)"
"$VENV/bin/pip" install --quiet kokoro soundfile

# --- CLI -------------------------------------------------------------------

bold "→ installing CLI: $BIN_DIR/aloud"
sed "1s|^#!.*|#!$VENV/bin/python3|" "$REPO_DIR/bin/aloud" > "$BIN_DIR/aloud"
chmod +x "$BIN_DIR/aloud"

# --- daemon (launchd) ------------------------------------------------------

bold "→ registering the daemon (starts at login, keeps the model warm)"
# warm-up language from the system locale (Kokoro lang codes)
case "${LANG:-en}" in
  es*) WARM="e" ;; fr*) WARM="f" ;; it*) WARM="i" ;; pt*) WARM="p" ;;
  hi*) WARM="h" ;; ja*) WARM="j" ;; zh*) WARM="z" ;; *) WARM="a" ;;
esac
sed -e "s|__PYTHON__|$VENV/bin/python3|g" \
    -e "s|__ALOUD__|$BIN_DIR/aloud|g" \
    -e "s|__HOME__|$HOME|g" \
    -e "s|__WARM__|$WARM|g" \
    "$REPO_DIR/launchd/com.aloud.daemon.plist.tmpl" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"

# --- Hammerspoon UI --------------------------------------------------------

bold "→ installing the UI (Hammerspoon module)"
mkdir -p "$HOME/.hammerspoon"
cp "$REPO_DIR/hammerspoon/aloud.lua" "$HOME/.hammerspoon/aloud.lua"
INIT="$HOME/.hammerspoon/init.lua"
touch "$INIT"
if ! grep -q 'require("aloud")' "$INIT"; then
  printf '\nrequire("aloud")\n' >> "$INIT"
fi
open -a Hammerspoon

echo
bold "✓ aloud is installed"
cat << 'EOF'

  Next steps:
  1. If macOS asks, grant Hammerspoon Accessibility permission
     (System Settings → Privacy & Security → Accessibility).
  2. Select any text and press ⌥⌘L — it reads aloud.
     ⌥⌘K stops · ⌥⌘H searches your reading history.
  3. Pick your voice and language in the 🔊 menu bar icon.

  CLI: aloud "hello" · aloud --history · aloud --last
EOF
