# outloud

Free, open-source, local text-to-speech for macOS. Hammerspoon captures selected text and provides hotkeys, a HUD, history search, and a menu bar; the Python CLI talks to a resident Kokoro daemon and mpv. The `site/` directory is a static website. There is no iOS app, Xcode project, subscription, RevenueCat integration, or analytics.

## Never compromise on

1. Keep reading local and private: no cloud text processing, accounts, or telemetry.
2. Preserve the CLI and Hammerspoon controls for read, stop, pause/resume, replay, speed, and history.
3. Do not alter or delete a user's reading history or cached audio as part of development setup.

## Glossary

- **user** — the person running outloud on a Mac. **CEO** — Eloi, who directs the agents.
- **daemon** — resident Python process that keeps Kokoro warm; **HUD** — Hammerspoon's floating playback controls.

## The ways to hurt yourself

1. Kill only processes you started and recorded; never kill by name or pattern.
2. Do not run `install.sh` or `uninstall.sh` as a test: they change Homebrew packages, login services, and the user's Hammerspoon setup.
3. Do not point tests at the user's `~/Library/Application Support/Outloud` history or live daemon sockets.

## Run and test

- Setup: `./scripts/setup-worktree.sh` runs in new T3 worktrees; wait for `.t3/setup-done` or inspect `.t3/setup-failed`.
- Test: `bash -n install.sh uninstall.sh scripts/setup-worktree.sh site/deploy.sh && python3 -c 'import ast; ast.parse(open("bin/outloud").read())'`. There is no automated runtime test suite or build step.
- Website preview: `python3 -m http.server 8000 --directory site`, then open `http://localhost:8000` (choose another port if occupied).
- App installation for a real Mac: `./install.sh` per README; it installs Kokoro, mpv, Hammerspoon, a launchd agent, and the CLI. Use only with explicit intent to modify that Mac.
- No `.env*` files are currently present in the main checkout; setup links them if added later. The current app requires no API keys.

## Hit every surface

Check CLI arguments and Hammerspoon hotkeys/HUD/menu together when changing playback or history. For user-facing changes, check README, website, and docs. Consider missing selection, stopped playback, and absent daemon paths.

## Verifying

- For logic bugs, show the failing behavior first, then verify the fix. For visual changes, compare before and after screenshots.
- Run the relevant syntax check and manual behavior check for changed surfaces. Do not use sleeps or retries to mask failures.

## Where code lives

- `bin/outloud` — Python CLI, daemon, mpv control, history, and Kokoro synthesis.
- `hammerspoon/outloud.lua` — selection capture, hotkeys, HUD, menu, and history UI.
- `install.sh`, `uninstall.sh`, `launchd/` — macOS installation and daemon service.
- `site/` — static landing page and docs; `docs/` — launch materials.

## Pull requests

Open only when asked. Use a conventional title and include the problem, fix, and proof; UI changes need images.
