#!/bin/bash
# aloud uninstaller — removes everything except your reading history.
# Delete "~/Library/Application Support/Aloud" yourself if you also want that gone.
set -uo pipefail

PLIST="$HOME/Library/LaunchAgents/com.aloud.daemon.plist"

echo "Uninstalling aloud…"
launchctl unload "$PLIST" 2>/dev/null
rm -f "$PLIST"
rm -f /opt/homebrew/bin/aloud /usr/local/bin/aloud
rm -rf "$HOME/.aloud"
rm -f "$HOME/.cache/aloud-daemon.sock" "$HOME/.cache/aloud-mpv.sock" \
      "$HOME/.cache/aloud-daemon.log"
rm -f "$HOME/.hammerspoon/aloud.lua"
if [ -f "$HOME/.hammerspoon/init.lua" ]; then
  sed -i '' '/require("aloud")/d' "$HOME/.hammerspoon/init.lua"
fi
echo "✓ done. (Hammerspoon and mpv were left installed; your history is in"
echo "  ~/Library/Application Support/Aloud if you want to delete it too.)"
