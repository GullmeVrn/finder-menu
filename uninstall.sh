#!/bin/bash
# Disables the Finder extension and removes Finder Menu from ~/Applications.
set -euo pipefail

APP="${DEST:-$HOME/Applications}/Finder Menu.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

pluginkit -e ignore -i local.findermenu.extension 2>/dev/null || true
pluginkit -r "$APP/Contents/PlugIns/FinderMenuExtension.appex" 2>/dev/null || true
pkill -f FinderMenuExtension.appex 2>/dev/null || true
[ -d "$APP" ] && "$LSREGISTER" -u "$APP" && rm -rf "$APP"

echo "Finder Menu removed."
