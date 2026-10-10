import Cocoa
import FinderSync

@objc(FinderMenuSync)
class FinderMenuSync: FIFinderSync {
    // Offered under "Open Folder With", in this order; only installed apps are shown.
    private static let editors: [(id: String, name: String)] = [
        ("com.microsoft.VSCode", "Visual Studio Code"),
        ("com.microsoft.VSCodeInsiders", "VS Code Insiders"),
        ("com.todesktop.230313mzl4w4u92", "Cursor"),
        ("com.exafunction.windsurf", "Windsurf"),
        ("com.google.antigravity", "Antigravity"),
        ("dev.zed.Zed", "Zed"),
        ("com.sublimetext.4", "Sublime Text"),
        ("com.sublimetext.3", "Sublime Text 3"),
        ("com.jetbrains.intellij", "IntelliJ IDEA"),
        ("com.jetbrains.intellij.ce", "IntelliJ IDEA CE"),
        ("com.jetbrains.pycharm", "PyCharm"),
        ("com.jetbrains.pycharm.ce", "PyCharm CE"),
        ("com.jetbrains.WebStorm", "WebStorm"),
        ("com.jetbrains.goland", "GoLand"),
        ("com.jetbrains.rider", "Rider"),
        ("com.jetbrains.CLion", "CLion"),
        ("com.jetbrains.rustrover", "RustRover"),
        ("com.jetbrains.PhpStorm", "PhpStorm"),
        ("com.jetbrains.rubymine", "RubyMine"),
        ("com.jetbrains.datagrip", "DataGrip"),
        ("com.jetbrains.fleet", "Fleet"),
        ("com.google.android.studio", "Android Studio"),
        ("com.apple.dt.Xcode", "Xcode"),
        ("com.panic.Nova", "Nova"),
        ("com.barebones.bbedit", "BBEdit"),
    ]

    override init() {
        super.init()
        // Show the menu in every folder on the Mac.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else { return nil }
        let menu = NSMenu(title: "")
        menu.addItem(withTitle: "New File…", action: #selector(newFile(_:)), keyEquivalent: "")
            .image = Self.symbol("doc.badge.plus")
        menu.addItem(withTitle: "Open Terminal Here", action: #selector(openTerminal(_:)), keyEquivalent: "")
            .image = Self.symbol("terminal")
        let openWith = menu.addItem(withTitle: "Open Folder With", action: nil, keyEquivalent: "")
        openWith.image = Self.symbol("arrow.up.forward.app")
        openWith.submenu = openWithMenu()
        menu.addItem(withTitle: "Copy Path", action: #selector(copyPath(_:)), keyEquivalent: "")
            .image = Self.symbol("doc.on.doc")
        if let dir = currentFolder, dir.path != "/" {
            menu.addItem(withTitle: "Go to Parent Folder", action: #selector(goUp(_:)), keyEquivalent: "")
                .image = Self.symbol("arrow.turn.left.up")
        }
        return menu
    }

    private static func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func openWithMenu() -> NSMenu {
        let sub = NSMenu(title: "")
        for (i, editor) in Self.editors.enumerated() {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: editor.id) else { continue }
            let item = sub.addItem(withTitle: editor.name, action: #selector(openWith(_:)), keyEquivalent: "")
            item.tag = i // Finder copies the menu, so the tag is how the action knows which app was picked.
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
        }
        if !sub.items.isEmpty { sub.addItem(.separator()) }
        sub.addItem(withTitle: "Other App…", action: #selector(openWithOther(_:)), keyEquivalent: "")
            .image = Self.symbol("ellipsis.circle")
        return sub
    }

    @objc func goUp(_ sender: AnyObject?) {
        guard let dir = currentFolder else { return }
        callHelper("up", dir.path)
    }

    private var currentFolder: URL? { FIFinderSyncController.default().targetedURL() }
    private var selection: [URL] { FIFinderSyncController.default().selectedItemURLs() ?? [] }
    // Right-clicked a single item → that item (the helper uses its folder); otherwise the folder you're in.
    private var clickedTarget: URL? { selection.count == 1 ? selection[0] : currentFolder }

    @objc func openWith(_ sender: AnyObject?) {
        guard let tag = (sender as? NSMenuItem)?.tag, Self.editors.indices.contains(tag),
              let target = clickedTarget else { return }
        callHelper("openwith", target.path, app: Self.editors[tag].id)
    }

    @objc func openWithOther(_ sender: AnyObject?) {
        guard let target = clickedTarget else { return }
        callHelper("openwith", target.path)
    }

    @objc func newFile(_ sender: AnyObject?) {
        guard let dir = currentFolder else { return }
        callHelper("newfile", dir.path)
    }

    @objc func openTerminal(_ sender: AnyObject?) {
        guard let target = clickedTarget else { return }
        callHelper("terminal", target.path)
    }

    @objc func copyPath(_ sender: AnyObject?) {
        let urls = selection.isEmpty ? [currentFolder].compactMap { $0 } : selection
        guard !urls.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
    }

    // The extension is sandboxed, so file creation and app launching happen in the helper app.
    private func callHelper(_ action: String, _ path: String, app: String? = nil) {
        var c = URLComponents()
        c.scheme = "findermenu"
        c.host = action
        c.queryItems = [URLQueryItem(name: "path", value: path)]
        if let app { c.queryItems?.append(URLQueryItem(name: "app", value: app)) }
        if let url = c.url { NSWorkspace.shared.open(url) }
    }
}
