<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Finder Menu icon">
</p>

<h1 align="center">Finder Menu</h1>

<p align="center">Tiny Finder extension adding the right-click options macOS is missing.</p>

<p align="center">
  <img src="docs/menu.png" width="552" alt="Finder right-click menu with New File, Open Terminal Here, Open Folder With (VS Code, Sublime Text, IntelliJ IDEA, PyCharm, Xcode…), Copy Path and Go to Parent Folder">
</p>

Right-click **empty space** in any folder, with nothing selected:

| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Menu item | What it does |
|:-:|---|---|
| <picture><source media="(prefers-color-scheme: dark)" srcset="docs/icons/new-file-dark.png"><img src="docs/icons/new-file.png" width="20" height="20" alt=""></picture> | **New&nbsp;File…** | Asks for a name with any extension (`notes.md`, `main.py`, `.env`), creates it in the current folder and selects it. Never overwrites. |
| <picture><source media="(prefers-color-scheme: dark)" srcset="docs/icons/terminal-dark.png"><img src="docs/icons/terminal.png" width="20" height="20" alt=""></picture> | **Open&nbsp;Terminal&nbsp;Here** | Opens a terminal in the current folder: iTerm2, Ghostty, Warp, WezTerm, kitty or Alacritty if you have one, otherwise Terminal. [Pick your own](#choosing-a-terminal). |
| <picture><source media="(prefers-color-scheme: dark)" srcset="docs/icons/open-with-dark.png"><img src="docs/icons/open-with.png" width="20" height="20" alt=""></picture> | **Open&nbsp;Folder&nbsp;With&nbsp;▸** | Opens the current folder in an IDE or editor. Lists the ones you have installed (VS Code, Cursor, Windsurf, Zed, Sublime Text, JetBrains IDEs, Android Studio, Xcode…), plus **Other App…** to pick any app. |
| <picture><source media="(prefers-color-scheme: dark)" srcset="docs/icons/copy-path-dark.png"><img src="docs/icons/copy-path.png" width="20" height="20" alt=""></picture> | **Copy&nbsp;Path** | Copies the current folder's full path. |
| <picture><source media="(prefers-color-scheme: dark)" srcset="docs/icons/parent-folder-dark.png"><img src="docs/icons/parent-folder.png" width="20" height="20" alt=""></picture> | **Go&nbsp;to&nbsp;Parent&nbsp;Folder** | Moves the window up one level, even when Finder's Back button is greyed out (e.g. a window opened with `open .`). |

Right-clicking a file or folder works too: **Copy Path** copies the selected items' paths, and **Open Terminal Here** and **Open Folder With** use the selected folder.

## Install

**With Homebrew:**

```bash
brew install nikgrbn/tap/finder-menu
finder-menu enable
```

Run `finder-menu enable` again after `brew upgrade finder-menu`.

**Or from source:**

```bash
git clone https://github.com/nikgrbn/finder-menu.git
cd finder-menu
./install.sh
```

Either way, the app is built on your machine, installed to `~/Applications/Finder Menu.app` and the Finder extension is turned on. There's nothing to launch: Finder loads the extension by itself, including after a restart.

The first time you use **Go to Parent Folder**, macOS asks whether Finder Menu can control Finder. Click **OK**, because that's how it moves the window.

### Choosing a terminal

**Open Terminal Here** uses the first terminal it finds, in this order: iTerm2, Ghostty, Warp, WezTerm, kitty, Alacritty, Terminal. To pick one yourself:

```bash
finder-menu terminal Ghostty
```

Any app name works. `finder-menu terminal` shows the current choice, and `finder-menu terminal auto` goes back to picking automatically. If you installed from source, run `scripts/finder-menu` from the repo folder instead.

## Uninstall

With Homebrew:

```bash
finder-menu disable
brew uninstall finder-menu
```

From source:

```bash
./uninstall.sh
```

## Troubleshooting

- **Menu items don't appear:** hold ⌥, right-click Finder in the Dock and choose **Relaunch**. Also check that **Finder Menu** is turned on under System Settings → General → Login Items & Extensions → Finder extensions.
- **Asked for permission again after reinstalling:** expected. Every build is signed locally with a new signature, so macOS asks again.

## How it works

- `Sources/FinderMenuExtension` is a [Finder Sync extension](https://developer.apple.com/documentation/findersync) that adds the menu items to every folder. Finder extensions must run sandboxed, so this part only reads the clicked folder and copies paths.
- `Sources/FinderMenu` is a small helper app that isn't sandboxed and has no Dock icon. The extension hands it actions through a `findermenu://` URL, and the helper ignores those URLs from anything else. It creates the files, opens the terminal and moves the Finder window, then quits.
- `Sources/Shared/Editors.swift` is the IDE list. The extension builds the submenu from it, and the helper refuses links naming any app that isn't on it.
- `scripts/build.sh` compiles and signs the app; `scripts/finder-menu enable|disable` copies it into `~/Applications` and turns the extension on or off. `install.sh`, `uninstall.sh` and the Homebrew formula all use these two.
- `scripts/make-icon.swift` draws the app icon in code and regenerates `Resources/AppIcon.icns` and `docs/icon.png`.

## Privacy & security

You build Finder Menu yourself from this source, so there's no downloaded app to trust. Everything below can be checked in the code:

- **No network access.** There's no networking code, so nothing is sent anywhere: no telemetry, no analytics, no update checks.
- **Small enough to read.** About 350 lines of Swift and 130 lines of shell scripts (`install.sh` and `scripts/`). Read them before you run them.
- **Sandboxed Finder extension.** It can't read your files. It only gets the folder you right-click and the items you select.
- **The helper only acts when you pick a menu item.** It creates an empty file with the name you type (never overwriting anything), opens a terminal or an app in a folder, or moves the Finder window up a level.
- **Links from other apps are ignored.** The extension sends actions to the helper as `findermenu://` links. Other apps can send those links too, and so can a website after your browser asks you. Opening a folder they choose in a terminal or IDE could run code from it, so the helper checks the code signature of whatever sent each link and ignores any that didn't come from its own Finder extension. On top of that, it only acts on folders that exist, only opens apps from its built-in IDE list (or one you pick yourself), and always asks before creating a file.
- **One permission.** Go to Parent Folder asks once to control Finder. Finder Menu doesn't ask for Full Disk Access, Accessibility or anything else.
- **Signed locally, not notarized.** `install.sh` signs the build on your Mac ("Sign to Run Locally"). It isn't notarized by Apple, because there's no download for Apple to check.

Found a security problem? See [SECURITY.md](SECURITY.md).

## License

MIT
