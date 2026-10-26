#!/usr/bin/env bash
# Runs automatically when T3 creates a worktree for a new thread (t3.json → runOnWorktreeCreate).
# Agents can start before it ends: .t3/setup-running holds this PID until it becomes
# .t3/setup-done or .t3/setup-failed (with the error tail), so they wait instead of racing it.
set -uo pipefail

WT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${T3CODE_PROJECT_ROOT:-}"
M="$WT/.t3"; mkdir -p "$M"
rm -f "$M/setup-done" "$M/setup-failed"
echo $$ > "$M/setup-running"
LOG="$M/setup.log"; : > "$LOG"

finish() {
  local code=$?
  if [[ $code -eq 0 ]]; then touch "$M/setup-done"
  else { echo "Setup exited with code $code."; tail -n 30 "$LOG"; } > "$M/setup-failed"; fi
  rm -f "$M/setup-running"
}
trap finish EXIT
trap 'exit 1' INT TERM HUP

cd "$WT" || exit 1

# Link the main checkout's env files (replace only symlinks, never real files).
if [[ -n "$ROOT" && "$ROOT" != "$WT" ]]; then
  if [[ ! -d "$ROOT" ]]; then echo "Project root does not exist: $ROOT" >> "$LOG"; exit 1; fi
  while IFS= read -r -d '' src; do
    rel="${src#"$ROOT"/}"; dst="$WT/$rel"
    if [[ -e "$dst" && ! -L "$dst" ]]; then continue; fi
    mkdir -p "$(dirname "$dst")" || exit 1
    ln -sfn "$src" "$dst" || exit 1
  done < <(find "$ROOT" -maxdepth 3 -type f \( -name ".env" -o -name ".env.*" \) ! -name "*.example" \
            -not -path "*/node_modules/*" -not -path "*/.git/*" -print0)
fi

# No dependency install or project generation: the CLI uses Python's standard
# library until speech starts, and this repo has no lockfile or Xcode project.
exit 0
