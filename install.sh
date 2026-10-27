#!/bin/bash
# outloud installer — free, local text-to-speech for macOS
# Usage: ./install.sh                     (from a cloned repo)
#    or: curl -fsSL https://raw.githubusercontent.com/EloiGils/outloud/main/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/EloiGils/outloud.git"
# Kokoro 0.9.x supports Python >=3.10,<3.13; prefer the newest supported one.
PY_MIN=10
PY_MAX=12
PY_PREFERRED=(3.12 3.11 3.10)

# --- helpers (tests source these alone with OUTLOUD_LIB_ONLY=1) -------------

bold() { printf "\033[1m%s\033[0m\n" "$1"; }

# python_version CMD -> prints "3.12" for a working interpreter, fails otherwise.
python_version() {
  "$1" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null
}

# python_supported CMD -> succeeds when CMD is Python 3.PY_MIN..3.PY_MAX.
python_supported() {
  local v major minor
  v="$(python_version "$1")" || return 1
  major="${v%%.*}"; minor="${v#*.}"
  [ "$major" = "3" ] && [ "$minor" -ge "$PY_MIN" ] && [ "$minor" -le "$PY_MAX" ]
}

# find_python -> prints the first supported interpreter, fails if there is none.
# Order: python3.12, python3.11, python3.10 (PATH, then Homebrew), then plain python3.
find_python() {
  local v cmd
  for v in "${PY_PREFERRED[@]}"; do
    for cmd in "python$v" "/opt/homebrew/opt/python@$v/bin/python$v" "/usr/local/opt/python@$v/bin/python$v"; do
      if command -v "$cmd" >/dev/null 2>&1 && python_supported "$cmd"; then
        command -v "$cmd"; return 0
      fi
    done
  done
  if command -v python3 >/dev/null 2>&1 && python_supported python3; then
    command -v python3; return 0
  fi
  return 1
}

# latest_release_tag URL -> prints the highest v* tag of the repo, empty if none.
latest_release_tag() {
  git ls-remote --tags --refs --sort=-v:refname "$1" 'v*' 2>/dev/null \
    | sed -n '1s|.*refs/tags/||p' || true
}

# shellcheck disable=SC2317
if [ -n "${OUTLOUD_LIB_ONLY:-}" ]; then return 0 2>/dev/null || exit 0; fi

# --- source checkout -------------------------------------------------------

REPO_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ ! -f "$REPO_DIR/bin/outloud" ]; then
  # running standalone (curl | bash): fetch a release tag, not the moving main branch
  REF="${OUTLOUD_REF:-$(latest_release_tag "$REPO_URL")}"
  if [ -z "$REF" ]; then
    echo "! no release tag found, falling back to the main branch" >&2
    REF="main"
  fi
  echo "-> downloading outloud ($REF)..."
  REPO_DIR="$HOME/.outloud/src"
  rm -rf "$REPO_DIR"
  mkdir -p "$REPO_DIR"
  git clone --quiet --depth 1 --branch "$REF" "$REPO_URL" "$REPO_DIR"
fi
OUTLOUD_HOME="$HOME/.outloud"
VENV="$OUTLOUD_HOME/venv"
BIN_DIR="/opt/homebrew/bin"
[ -d "$BIN_DIR" ] || BIN_DIR="/usr/local/bin"
PLIST="$HOME/Library/LaunchAgents/com.outloud.daemon.plist"

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

mkdir -p "$OUTLOUD_HOME"

if [ -x "$VENV/bin/python3" ] && python_supported "$VENV/bin/python3"; then
  bold "→ reusing Python environment (~/.outloud/venv, Python $(python_version "$VENV/bin/python3"))"
else
  PY="$(find_python || true)"
  if [ -z "$PY" ]; then
    bold "→ no Python 3.$PY_MIN–3.$PY_MAX found; installing python@3.12 with Homebrew"
    brew install python@3.12 || true
    PY="$(find_python || true)"
  fi
  if [ -n "$PY" ]; then
    bold "→ creating Python environment (~/.outloud/venv, Python $(python_version "$PY"))"
    "$PY" -m venv --clear "$VENV"
  elif command -v uv >/dev/null 2>&1; then
    bold "→ creating Python environment with uv (~/.outloud/venv, Python 3.12)"
    uv venv --seed --python 3.12 --clear "$VENV"
  else
    cat >&2 << EOF
outloud needs Python 3.$PY_MIN to 3.$PY_MAX (the Kokoro voice model does not support
newer or older versions), and none was found. Homebrew could not install one either.

Install one yourself, then run ./install.sh again:
  brew install python@3.12
EOF
    exit 1
  fi
fi

"$VENV/bin/pip" install --quiet --upgrade pip
bold "→ installing Kokoro TTS (this downloads PyTorch; a few minutes the first time)"
"$VENV/bin/pip" install --quiet -r "$REPO_DIR/requirements.txt"

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
