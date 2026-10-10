#!/bin/bash
# Builds Finder Menu, installs it into ~/Applications and enables the Finder extension.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Finder Menu"
EXT_ID="local.findermenu.extension"
DEST="${DEST:-$HOME/Applications}"
TARGET="$(uname -m)-apple-macos13.0"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Build outside the repo so macOS never registers a second copy of the extension.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/$APP_NAME.app"
EXT="$APP/Contents/PlugIns/FinderMenuExtension.appex"

echo "Building..."
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS"
cp Resources/App-Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Resources/Extension-Info.plist "$EXT/Contents/Info.plist"

xcrun swiftc -swift-version 5 -O -sdk "$SDK" -target "$TARGET" \
  -module-name FinderMenuExtension -parse-as-library -application-extension \
  -framework Cocoa -framework FinderSync -Xlinker -e -Xlinker _NSExtensionMain \
  Sources/FinderMenuExtension/*.swift Sources/Shared/*.swift -o "$EXT/Contents/MacOS/FinderMenuExtension"
xcrun swiftc -swift-version 5 -O -sdk "$SDK" -target "$TARGET" \
  -module-name FinderMenu -framework Cocoa \
  Sources/FinderMenu/*.swift Sources/Shared/*.swift -o "$APP/Contents/MacOS/FinderMenu"

# Ad-hoc signature ("Sign to Run Locally"). Finder extensions must be sandboxed.
codesign --force -s - --entitlements Resources/Extension.entitlements "$EXT"
codesign --force -s - "$APP"

echo "Installing to $DEST..."
pkill -f FinderMenuExtension.appex 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/$APP_NAME.app"
cp -R "$APP" "$DEST/"
"$LSREGISTER" -f "$DEST/$APP_NAME.app"
pluginkit -a "$DEST/$APP_NAME.app/Contents/PlugIns/FinderMenuExtension.appex"
pluginkit -e use -i "$EXT_ID"

echo "Done. Right-click inside any Finder folder."
