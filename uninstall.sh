#!/bin/bash
# Disables the Finder extension and removes Finder Menu from ~/Applications.
exec "$(dirname "$0")/scripts/finder-menu" disable
