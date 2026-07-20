#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILT="$ROOT/dist/Codex Theme Studio.app"
DESTINATION="$HOME/Applications/Codex Theme Studio.app"

"$ROOT/scripts/build-app.sh" "$BUILT"

# Stop the currently installed binary before replacing its bundle. Using
# `open -n` after an in-place replacement can otherwise leave two menu extras.
/usr/bin/pkill -TERM -x CodexThemeStudio 2>/dev/null || true
for _ in {1..30}; do
  if ! /usr/bin/pgrep -x CodexThemeStudio >/dev/null 2>&1; then
    break
  fi
  /bin/sleep 0.1
done
if /usr/bin/pgrep -x CodexThemeStudio >/dev/null 2>&1; then
  /usr/bin/pkill -KILL -x CodexThemeStudio 2>/dev/null || true
fi

# The previous product used a different bundle identifier, so SMAppService in
# the new app cannot unregister it. Remove the recoverable Login Items entry
# during this explicit migration; the legacy app itself is left untouched.
/usr/bin/osascript -e \
  'tell application "System Events" to delete every login item whose name is "Codex Dream Skin"' \
  >/dev/null 2>&1 || true

/bin/mkdir -p "$HOME/Applications"
/bin/rm -rf "$DESTINATION"
/usr/bin/ditto "$BUILT" "$DESTINATION"
/usr/bin/codesign --verify --deep --strict "$DESTINATION"
/usr/bin/open "$DESTINATION"

printf 'Installed: %s\n' "$DESTINATION"
if [ ! -x "$HOME/.codex/codex-dream-skin-studio/scripts/status-dream-skin-macos.sh" ]; then
  printf 'Notice: no compatible Dream Skin provider was found; browsing and package validation remain available.\n'
fi
