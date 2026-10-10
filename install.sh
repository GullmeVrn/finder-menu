#!/bin/bash
# Builds Finder Menu, installs it into ~/Applications and enables the Finder extension.
set -euo pipefail
cd "$(dirname "$0")"

# Build outside the repo so macOS never registers a second copy of the extension.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Building..."
scripts/build.sh "$WORK"
scripts/finder-menu enable "$WORK/Finder Menu.app"
