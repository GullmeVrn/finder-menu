# Security policy

## Reporting a vulnerability

Please report security problems privately, not in a public issue. Open the repo's **Security** tab and choose **Report a vulnerability**, or go straight to https://github.com/nikgrbn/finder-menu/security/advisories/new.

Include what you found, how to reproduce it, and your macOS version. I'll reply as soon as I can.

## What's in scope

- The helper app's handling of `findermenu://` links (`Sources/FinderMenu/main.swift`)
- The Finder extension (`Sources/FinderMenuExtension`)
- `install.sh` and `uninstall.sh`

Especially anything that lets another app or a website make Finder Menu do something you didn't ask for.

## Supported versions

Only the latest version on `main` gets fixes. To update with Homebrew:

```bash
brew update && brew upgrade finder-menu
finder-menu enable
```

Or from source:

```bash
git pull && ./install.sh
```
