# outloud — launch kit

Live site: https://eloigils.github.io/outloud/ · Repo: https://github.com/EloiGils/outloud

The goal is reach, not revenue. Lead with the *pain*, not the tech. Your real
story — reading long text is hard, Speechify is expensive, Apple's voices are
from 2005 — is the hook. Post as yourself, be honest it's a personal project.

Best-first order to post (space them out over a few days, don't blast all at once):

---

## 1. r/macapps  — the warmest crowd for a free Mac tool

**Title:** I built a free, open-source Speechify alternative that reads any
selected text aloud — 100% local, no subscription

**Body:**
> I read slower than I can listen, and long articles/PDFs are a slog. Speechify
> is $139/yr and the built-in macOS voices sound ancient, so I built my own.
>
> **outloud** — select text in any app, press ⌥⌘L, a natural voice reads it aloud.
> Everything runs locally on your Mac (open-source Kokoro voice model): no cloud,
> no account, no telemetry. Free forever, MIT licensed.
>
> - Works in any app — browser, PDF, Slack, even terminals
> - Starts speaking in ~1.5s even for long text
> - Live speed control + exact pause, reading history you can re-listen to
> - 9 languages, 50+ voices
>
> Site + one-command install: https://eloigils.github.io/outloud/
> Code: https://github.com/EloiGils/outloud
>
> Happy to answer anything — it's my personal project.

---

## 2. r/ADHD — your authentic angle (post the story, not a product pitch)

**Title:** Reading long text is exhausting for me, so I made a free tool that
reads anything on my screen aloud

**Body:**
> Text-to-speech is the only way I get through long articles, but the good apps
> are subscriptions and the free ones sound terrible. I built a free, open-source
> one for Mac: highlight any text anywhere, hit a shortcut, it reads it in a
> natural voice. No account, runs on your own machine.
>
> Sharing in case it helps someone else who processes things better by ear.
> Free, no catch: https://eloigils.github.io/outloud/

*(Read the subreddit's self-promo rules first; frame it as sharing a personal
tool, engage in comments, don't drop-and-run.)*

---

## 3. Hacker News — Show HN (post Tue–Thu morning US time)

**Title:** Show HN: outloud – free, local text-to-speech for macOS (Kokoro + mpv)

**URL:** https://github.com/EloiGils/outloud

**First comment (post it yourself right away):**
> Author here. I wanted Speechify's "read anything aloud" without the
> subscription or sending my text to a server, so I wired the open-source
> Kokoro-82M model to a global hotkey. Technical bits HN might like:
>
> - A resident daemon keeps the model warm and synthesizes sentence-by-sentence,
>   streaming into mpv — ~1.5s to first audio regardless of text length.
> - mpv (not afplay) so pause is exact and speed is live with pitch correction.
> - Surprise: on Apple Silicon Kokoro runs ~2.3× *faster* on CPU than MPS,
>   because one istftnet op falls back per call.
> - UI is Hammerspoon so there's no app bundle to notarize (yet).
>
> It's MIT. Feedback welcome, especially on the Spanish/multilingual pronunciation.

---

## 4. X / Twitter — short, with the demo GIF attached

> Reading long text is hard for me and Speechify is $139/yr, so I built a free
> open-source alternative.
>
> outloud: select any text on your Mac, press ⌥⌘L, it reads it aloud. Local,
> private, 50+ voices, $0 forever.
>
> https://eloigils.github.io/outloud/

---

## Before you post

1. **Add a demo GIF** to the README and the site — 8s: select text → ⌥⌘L → the
   HUD appears and the voice plays. It's the single biggest conversion lever;
   most people decide from the GIF alone.
2. Double-check the install command works from a clean shell.
3. Have the repo's Issues enabled so early users can report + you look responsive.
4. Reply fast in the first 2 hours on every platform — early engagement is what
   the ranking algorithms reward.
