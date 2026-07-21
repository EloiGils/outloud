#!/bin/bash
# outloud installer — free, local text-to-speech for macOS
# Usage: ./install.sh                     (from a cloned repo)
#    or: curl -fsSL https://raw.githubusercontent.com/EloiGils/outloud/main/install.sh | bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ ! -f "$REPO_DIR/bin/outloud" ]; then
  # running standalone (curl | bash): fetch the repo first
  echo "-> downloading outloud..."
  REPO_DIR="$HOME/.outloud/src"
  rm -rf "$REPO_DIR"
  mkdir -p "$REPO_DIR"
  git clone --quiet --depth 1 https://github.com/EloiGils/outloud.git "$REPO_DIR"
fi
OUTLOUD_HOME="$HOME/.outloud"
VENV="$OUTLOUD_HOME/venv"
BIN_DIR="/opt/homebrew/bin"
[ -d "$BIN_DIR" ] || BIN_DIR="/usr/local/bin"
PLIST="$HOME/Library/LaunchAgents/com.outloud.daemon.plist"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }

bold "outloud installer"
echo

# --- prerequisites ---------------------------------------------------------

if [ "$(uname)" != "Darwin" ]; then
  echo "outloud only supports macOS." >&2; exit 1
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

bold "→ creating Python environment (~/.outloud/venv)"
mkdir -p "$OUTLOUD_HOME"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
bold "→ installing Kokoro TTS (this downloads PyTorch; a few minutes the first time)"
"$VENV/bin/pip" install --quiet kokoro soundfile

# --- CLI -------------------------------------------------------------------

bold "→ installing CLI: $BIN_DIR/outloud"
sed "1s|^#!.*|#!$VENV/bin/python3|" "$REPO_DIR/bin/outloud" > "$BIN_DIR/outloud"
chmod +x "$BIN_DIR/outloud"

# --- daemon (launchd) ------------------------------------------------------

bold "→ registering the daemon (starts at login, keeps the model warm)"
# warm-up language from the system locale (Kokoro lang codes)
case "${LANG:-en}" in
  es*) WARM="e" ;; fr*) WARM="f" ;; it*) WARM="i" ;; pt*) WARM="p" ;;
  hi*) WARM="h" ;; ja*) WARM="j" ;; zh*) WARM="z" ;; *) WARM="a" ;;
esac
sed -e "s|__PYTHON__|$VENV/bin/python3|g" \
    -e "s|__OUTLOUD__|$BIN_DIR/outloud|g" \
    -e "s|__HOME__|$HOME|g" \
    -e "s|__WARM__|$WARM|g" \
    "$REPO_DIR/launchd/com.outloud.daemon.plist.tmpl" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"

# --- Hammerspoon UI --------------------------------------------------------

bold "→ installing the UI (Hammerspoon module)"
mkdir -p "$HOME/.hammerspoon"
cp "$REPO_DIR/hammerspoon/outloud.lua" "$HOME/.hammerspoon/outloud.lua"
INIT="$HOME/.hammerspoon/init.lua"
touch "$INIT"
if ! grep -q 'require("outloud")' "$INIT"; then
  printf '\nrequire("outloud")\n' >> "$INIT"
fi
open -a Hammerspoon

echo
bold "✓ outloud is installed"
cat << 'EOF'

  Next steps:
  1. If macOS asks, grant Hammerspoon Accessibility permission
     (System Settings → Privacy & Security → Accessibility).
  2. Select any text and press ⌥⌘L — it reads aloud.
     ⌥⌘K stops · ⌥⌘H searches your reading history.
  3. Pick your voice and language in the 🔊 menu bar icon.

  CLI: outloud "hello" · outloud --history · outloud --last
EOF
