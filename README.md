# 🔊 aloud

**Free, open-source, local text-to-speech for macOS.**
Like [Handy](https://github.com/cjpais/Handy), but for reading aloud.

Select text in *any* app — browser, terminal, PDF, mail — press **⌥⌘L**, and a
natural voice reads it to you. Everything runs locally on your Mac: no cloud, no
API keys, no subscription, no telemetry. Ever.

## Features

- **Works everywhere** — one global hotkey reads the selection in any app
  (Accessibility API first, smart clipboard fallback, special handling for
  terminals with Secure Keyboard Entry).
- **Starts speaking in ~1-2 seconds**, no matter how long the text is: a
  resident daemon keeps the model warm and synthesizes sentence-by-sentence,
  streaming into the player while the rest is still being generated.
- **Floating HUD** while reading: live speed control (−/+, applied instantly
  mid-playback with pitch correction), exact pause/resume, instant replay, stop.
- **Reading history** with cached audio — re-listen to anything instantly from
  the 🔊 menu bar icon or the Spotlight-style search (**⌥⌘H**).
- **9 languages, 50+ voices** via [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M):
  English (US/UK), Spanish, French, Italian, Portuguese, Hindi, Japanese*, Chinese*.
- **Scriptable CLI**: `aloud "text"`, `echo text | aloud`, `aloud --history`,
  `aloud --last` — build your own integrations.

*\*Japanese and Chinese need extras: `~/.aloud/venv/bin/pip install "misaki[ja]"` / `"misaki[zh]"`.*

## Install

Requires macOS and [Homebrew](https://brew.sh).

```bash
git clone https://github.com/YOUR_USER/aloud.git
cd aloud
./install.sh
```

The installer sets up: a private Python env with Kokoro (~2 GB incl. PyTorch),
[mpv](https://mpv.io) as the audio engine, a launchd daemon that keeps the
model warm from login, and the [Hammerspoon](https://www.hammerspoon.org)
UI module (hotkeys + HUD + menu bar). First run: grant Hammerspoon
Accessibility permission when macOS asks.

To remove everything: `./uninstall.sh`.

## Usage

| | |
|---|---|
| **⌥⌘L** | read the selected text aloud |
| **⌥⌘K** | stop |
| **⌥⌘H** | search your reading history |
| 🔊 menu bar | recent readings, voice & speed settings |
| HUD | `−  1.5×  +` live speed · ⏸ exact pause · 🔁 replay · ✕ |

```bash
aloud "read this sentence"       # CLI
cat article.md | aloud -l a      # pipe, English
aloud -l e --voice em_alex       # Spanish, male voice
aloud --history                  # list past readings
aloud --reread 20260721-134536   # re-listen (instant, cached audio)
```

## How it works

```
select text ──⌥⌘L──▶ Hammerspoon UI ──▶ aloud CLI ──▶ daemon (Kokoro warm, CPU)
                                                        │  sentence-by-sentence
                                                        ▼
                          HUD controls ◀──socket──▶ mpv (gapless playlist,
                                                    exact pause, live speed)
```

Design notes learned the hard way:

- `afplay` can't truly pause (the audio clock keeps running) — mpv's IPC
  socket gives exact pause and live speed with pitch correction.
- On Apple Silicon, Kokoro is **~2.3× faster on CPU than on MPS/GPU**
  (one istftnet op falls back per call). The daemon pins CPU on purpose.
- The first text chunk is cut extra-short (~30-90 chars) so the first audio
  lands in about a second; later chunks are full sentences.

## Roadmap

- [ ] Quality mode with [Qwen3-TTS](https://huggingface.co/Qwen) (MLX):
      best-in-class pronunciation + voice cloning from a 5s sample
- [ ] Pronunciation dictionary (per-user word overrides)
- [ ] Native app bundle (no Hammerspoon dependency)
- [ ] Homebrew tap: `brew install aloud`

## Credits

Standing on excellent shoulders: [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M)
(Apache-2.0) · [mpv](https://mpv.io) · [Hammerspoon](https://www.hammerspoon.org) ·
UX inspired by [Handy](https://github.com/cjpais/Handy) and Speechify.

## License

[MIT](LICENSE)
