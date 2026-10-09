# Finder Menu

Adds the right-click options that macOS Finder is missing. Right-click **empty space** in any folder, with nothing selected:

| Menu item | What it does |
|---|---|
| **New File…** | Asks for a name with any extension (`notes.md`, `main.py`, `.env`), creates it in the current folder and selects it. Never overwrites. |
| **Open Terminal Here** | Opens iTerm2 (or Terminal, if iTerm2 isn't installed) in the current folder. |
| **Copy Path** | Copies the current folder's full path. |
| **Go to Parent Folder** | Moves the window up one level, even when Finder's Back button is greyed out (e.g. a window opened with `open .`). |

Right-clicking a file or folder works too: **Copy Path** copies the selected items' paths and **Open Terminal Here** opens in the selected folder.

## Install

Requires macOS 13+ and Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/nikgrbn/finder-menu.git
cd finder-menu
./install.sh
```

The script builds the app on your machine, installs it to `~/Applications/Finder Menu.app` and enables the Finder extension. There's nothing to launch: Finder loads the extension by itself, including after a restart.

The first time you use **Go to Parent Folder**, macOS asks whether Finder Menu can control Finder. Click **OK**, because that's how it moves the window.

## Uninstall

```bash
./uninstall.sh
```

## Troubleshooting

- **Menu items don't appear:** hold ⌥, right-click Finder in the Dock and choose **Relaunch**. Also check that **Finder Menu** is turned on under System Settings → General → Login Items & Extensions → Finder extensions.
- **Asked for permission again after reinstalling:** expected. Every build is signed locally with a new signature, so macOS asks again.

## How it works

- `Sources/FinderMenuExtension` is a [Finder Sync extension](https://developer.apple.com/documentation/findersync) that adds the menu items to every folder. Finder extensions must run sandboxed, so this part only reads the clicked folder and copies paths.
- `Sources/FinderMenu` is a small helper app that isn't sandboxed and has no Dock icon. The extension hands it actions through a `findermenu://` URL. It creates the files, opens the terminal and moves the Finder window, then quits.

## License

MIT
