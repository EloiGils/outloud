#!/bin/bash
# outloud uninstaller — removes everything except your reading history.
# Delete "~/Library/Application Support/Outloud" yourself if you also want that gone.
set -uo pipefail

PLIST="$HOME/Library/LaunchAgents/com.outloud.daemon.plist"

echo "Uninstalling outloud…"
launchctl unload "$PLIST" 2>/dev/null
rm -f "$PLIST"
rm -f /opt/homebrew/bin/outloud /usr/local/bin/outloud
rm -rf "$HOME/.outloud"
rm -f "$HOME/.cache/outloud-daemon.sock" "$HOME/.cache/outloud-mpv.sock" \
      "$HOME/.cache/outloud-daemon.log"
rm -f "$HOME/.hammerspoon/outloud.lua"
if [ -f "$HOME/.hammerspoon/init.lua" ]; then
  sed -i '' '/require("outloud")/d' "$HOME/.hammerspoon/init.lua"
fi
echo "✓ done. (Hammerspoon and mpv were left installed; your history is in"
echo "  ~/Library/Application Support/Outloud if you want to delete it too.)"
