#!/bin/bash
# Build NextKey, install it to ~/Applications/NextKey.app, and relaunch it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="$HOME/Applications/NextKey.app"
pkill -x NextKey 2>/dev/null || true
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NextKey "$APP/Contents/MacOS/NextKey"
cp Info.plist "$APP/Contents/Info.plist"

# A stable signing identity keeps the Screen Recording grant across rebuilds.
# Ad-hoc signing (the fallback) changes the code hash on every build, so macOS
# treats each build as a new app and the permission must be re-granted.
IDENTITY="${NEXTKEY_SIGN_IDENTITY:-NextKey Local Signing}"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi

open "$APP"
echo "Installed and launched $APP"
