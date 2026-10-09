import Cocoa
import FinderSync

@objc(FinderMenuSync)
class FinderMenuSync: FIFinderSync {
    override init() {
        super.init()
        // Show the menu in every folder on the Mac.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else { return nil }
        let menu = NSMenu(title: "")
        menu.addItem(withTitle: "New File…", action: #selector(newFile(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Open Terminal Here", action: #selector(openTerminal(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy Path", action: #selector(copyPath(_:)), keyEquivalent: "")
        if let dir = currentFolder, dir.path != "/" {
            menu.addItem(withTitle: "Go to Parent Folder", action: #selector(goUp(_:)), keyEquivalent: "")
        }
        return menu
    }

    @objc func goUp(_ sender: AnyObject?) {
        guard let dir = currentFolder else { return }
        callHelper("up", dir.path)
    }

    private var currentFolder: URL? { FIFinderSyncController.default().targetedURL() }
    private var selection: [URL] { FIFinderSyncController.default().selectedItemURLs() ?? [] }

    @objc func newFile(_ sender: AnyObject?) {
        guard let dir = currentFolder else { return }
        callHelper("newfile", dir.path)
    }

    @objc func openTerminal(_ sender: AnyObject?) {
        // Right-clicked a single folder → open there; otherwise the folder you're in.
        let target = selection.count == 1 ? selection[0] : currentFolder
        guard let target else { return }
        callHelper("terminal", target.path)
    }

    @objc func copyPath(_ sender: AnyObject?) {
        let urls = selection.isEmpty ? [currentFolder].compactMap { $0 } : selection
        guard !urls.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
    }

    // The extension is sandboxed, so file creation and app launching happen in the helper app.
    private func callHelper(_ action: String, _ path: String) {
        var c = URLComponents()
        c.scheme = "findermenu"
        c.host = action
        c.queryItems = [URLQueryItem(name: "path", value: path)]
        if let url = c.url { NSWorkspace.shared.open(url) }
    }
}
