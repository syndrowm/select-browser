#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Select Browser.app"
EXEC="SelectBrowser"
BUILD_DIR="build"
STAGED="$BUILD_DIR/$APP_NAME"
DEST="/Applications/$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "Building $APP_NAME …"
rm -rf "$STAGED"
mkdir -p "$STAGED/Contents/MacOS" "$STAGED/Contents/Resources"
cp Info.plist "$STAGED/Contents/Info.plist"

swiftc -O \
  -o "$STAGED/Contents/MacOS/$EXEC" \
  Sources/*.swift \
  -framework AppKit -framework SwiftUI -framework CoreServices

# Ad-hoc sign so LaunchServices treats it as a stable app identity.
codesign --force --deep --sign - "$STAGED" >/dev/null 2>&1 || true

# Install a SINGLE canonical copy in /Applications. Keeping only one copy with
# this bundle id avoids LaunchServices picking a stale duplicate as the handler.
echo "Installing to $DEST …"
killall SelectBrowser 2>/dev/null || true
"$LSREGISTER" -u "$DEST" 2>/dev/null || true
rm -rf "$DEST"
cp -R "$STAGED" "$DEST"
"$LSREGISTER" -f "$DEST"

echo "Done: $DEST"
echo
echo "Launch it and click \"Set as Default Browser\","
echo "or set it in System Settings > Desktop & Dock > Default web browser."
