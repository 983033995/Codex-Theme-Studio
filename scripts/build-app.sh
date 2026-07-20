#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ROOT="$ROOT/app"
VERSION="$(/usr/bin/tr -d '\r\n' < "$ROOT/VERSION")"
OUTPUT="${1:-$ROOT/dist/Codex Theme Studio.app}"
CONFIGURATION="${THEME_STUDIO_BUILD_CONFIGURATION:-release}"

if [ "$(/usr/bin/uname -s)" != "Darwin" ]; then
  printf 'Codex Theme Studio can only be bundled on macOS.\n' >&2
  exit 1
fi

"$ROOT/scripts/test.sh"
/usr/bin/swift build --package-path "$APP_ROOT" -c "$CONFIGURATION"
BIN_DIR="$(/usr/bin/swift build --package-path "$APP_ROOT" -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE="$BIN_DIR/CodexThemeStudio"

TEMP_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-theme-studio.XXXXXX")"
trap '/bin/rm -rf "$TEMP_ROOT"' EXIT
APP="$TEMP_ROOT/Codex Theme Studio.app"
CONTENTS="$APP/Contents"
RESOURCES="$CONTENTS/Resources"
ICONSET="$TEMP_ROOT/AppIcon.iconset"
/bin/mkdir -p "$CONTENTS/MacOS" "$RESOURCES" "$ICONSET"
/bin/cp "$EXECUTABLE" "$CONTENTS/MacOS/CodexThemeStudio"
/bin/chmod 755 "$CONTENTS/MacOS/CodexThemeStudio"
/bin/cp "$APP_ROOT/Assets/GitHubMark.png" "$RESOURCES/GitHubMark.png"

make_icon() {
  local size="$1"
  local filename="$2"
  /usr/bin/sips -z "$size" "$size" "$APP_ROOT/Assets/AppIcon.png" --out "$ICONSET/$filename" >/dev/null
}
make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png
/usr/bin/iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

/usr/libexec/PlistBuddy -c 'Clear dict' "$CONTENTS/Info.plist" 2>/dev/null || /usr/bin/plutil -create xml1 "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDevelopmentRegion string zh_CN' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string Codex Theme Studio' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string CodexThemeStudio' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string io.codexthemestudio.menubar' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleInfoDictionaryVersion string 6.0' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleName string Codex Theme Studio' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${VERSION//./}" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 13.0' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool true' "$CONTENTS/Info.plist"

IDENTITY="${THEME_STUDIO_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | /usr/bin/head -n 1)"
fi
if [ -n "$IDENTITY" ]; then
  /usr/bin/codesign --force --deep --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
else
  /usr/bin/codesign --force --deep --sign - "$APP"
fi
/usr/bin/codesign --verify --deep --strict "$APP"
/bin/mkdir -p "$(/usr/bin/dirname "$OUTPUT")"
/bin/rm -rf "$OUTPUT"
/usr/bin/ditto "$APP" "$OUTPUT"
printf '%s\n' "$OUTPUT"
