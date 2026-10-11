import Cocoa
import os
import Security
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var handledURL = false
    private var settingsWindow: SettingsWindowController?

    func application(_ application: NSApplication, open urls: [URL]) {
        handledURL = true
        guard sentByOurExtension() else {
            // Logger rather than NSLog, which macOS logs as <private>. The links stay redacted.
            Logger(subsystem: "local.findermenu", category: "links")
                .notice("Ignored a findermenu:// link that didn't come from the Finder extension: \(urls.map(\.absoluteString))")
            finish()
            return
        }
        for url in urls {
            guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { continue }
            // Manage Templates… doesn't act on a folder.
            if c.host == "settings" { showSettings(); continue }
            guard let path = c.queryItems?.first(where: { $0.name == "path" })?.value,
                  let dir = folder(for: path) else { continue }
            switch c.host {
            case "newfile":
                // The file name comes from saved settings, not the URL — only the template id travels in the link.
                let templateID = c.queryItems?.first(where: { $0.name == "template" })?.value
                if let templateID {
                    guard let template = fileTemplate(id: templateID) else { continue }
                    newFile(in: dir, from: template)
                } else {
                    newFile(in: dir)
                }
            case "terminal": openTerminal(at: dir); return
            case "openwith":
                let appID = c.queryItems?.first(where: { $0.name == "app" })?.value
                // No app means "Other App…", where the user picks one themselves.
                if let appID, !editors.contains(where: { $0.id == appID }) { continue }
                openFolder(dir, appID: appID)
                return
            case "up": goUp(from: dir)
            default: break
            }
        }
        // A New File link can save a template while the settings window is open.
        settingsWindow?.reloadTemplates()
        finish()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launched by a menu item, a findermenu:// link arrives right away; otherwise the user opened the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.handledURL { self.showSettings() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    // Opened directly, the helper behaves like a regular app (Dock icon, ⌘W, ⌘Q) and quits with its window.
    private func showSettings() {
        if settingsWindow == nil {
            NSApp.setActivationPolicy(.regular)
            NSApp.mainMenu = makeMainMenu()
            let controller = SettingsWindowController()
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: controller.window,
                                                   queue: .main) { _ in NSApp.terminate(nil) }
            settingsWindow = controller
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: NSLocalizedString("Quit Finder Menu", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let windowMenu = NSMenu(title: NSLocalizedString("Window", comment: ""))
        windowMenu.addItem(withTitle: NSLocalizedString("Close", comment: ""), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let main = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            main.addItem(item)
        }
        return main
    }

    // A menu action is done. Quit, unless the settings window is open.
    private func finish() {
        if settingsWindow == nil { NSApp.terminate(nil) }
    }

    // Any app can send a findermenu:// link, and so can a website once the browser asks. Opening a
    // folder they pick in a terminal or IDE can run code from it (a git-aware prompt, an IDE's
    // folder-open tasks), so only accept links sent by the extension bundled with this app, matched
    // by code signature hash. Fails closed if the sender can't be identified (e.g. it has quit).
    private func sentByOurExtension() -> Bool {
        guard let token = NSAppleEventManager.shared().currentAppleEvent?
                  .attributeDescriptor(forKeyword: AEKeyword(keySenderAuditTokenAttr))?.data,
              let ext = Bundle.main.builtInPlugInsURL?.appendingPathComponent("FinderMenuExtension.appex")
        else { return false }
        var sender: SecCode?, bundled: SecStaticCode?, info: CFDictionary?, requirement: SecRequirement?
        guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributeAudit: token] as CFDictionary, [], &sender) == errSecSuccess,
              let sender,
              SecStaticCodeCreateWithPath(ext as CFURL, [], &bundled) == errSecSuccess,
              let bundled,
              SecCodeCopySigningInformation(bundled, [], &info) == errSecSuccess,
              let cdhash = (info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data,
              SecRequirementCreateWithString("cdhash H\"\(cdhash.map { String(format: "%02x", $0) }.joined())\"" as CFString,
                                             [], &requirement) == errSecSuccess
        else { return false }
        return SecCodeCheckValidity(sender, [], requirement) == errSecSuccess
    }

    // Only act on existing absolute paths. Files and packages such as .app bundles resolve to the
    // folder that contains them.
    private func folder(for path: String) -> String? {
        guard path.hasPrefix("/") else { return nil }
        let path = (path as NSString).standardizingPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
        let dir = isDir.boolValue && !isPackage(path) ? path : (path as NSString).deletingLastPathComponent
        return isPackage(dir) ? nil : dir
    }

    // Checks the real location, so a symlink to an .app counts as a package too.
    private func isPackage(_ path: String) -> Bool {
        NSWorkspace.shared.isFilePackage(atPath: (path as NSString).resolvingSymlinksInPath)
    }

    // Moves the Finder window showing `dir` (front-most match, else the front window) up one level.
    private func goUp(from dir: String) {
        func lit(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let parent = (dir as NSString).deletingLastPathComponent
        let script = """
        tell application "Finder"
            set dest to (POSIX file \(lit(parent)) as alias)
            repeat with w in Finder windows
                try
                    -- Case-only paths can name different folders on case-sensitive volumes.
                    considering case
                        if POSIX path of (target of w as alias) is \(lit(dir + "/")) then
                            set target of w to dest
                            return
                        end if
                    end considering
                end try
            end repeat
            if (count of Finder windows) > 0 then set target of front Finder window to dest
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error { NSLog("Finder Menu go-up failed: \(error)") }
    }

    // Uses the terminal picked in settings (or with `finder-menu terminal <app>`), otherwise the first installed one.
    private func openTerminal(at dir: String) {
        let ws = NSWorkspace.shared
        for id in [chosenTerminal].compactMap({ $0 }) + terminals.map(\.id) {
            guard let app = ws.urlForApplication(withBundleIdentifier: id) else { continue }
            let quit: (NSRunningApplication?, Error?) -> Void = { _, _ in DispatchQueue.main.async { self.finish() } }
            switch terminals.first(where: { $0.id == id })?.launch ?? .openFolder {
            case .openFolder:
                open(dir, withAppAt: app)
            case .link(let makeURL):
                guard let url = makeURL(dir) else { finish(); return }
                ws.open(url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: quit)
            case .arguments(let makeArguments):
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = makeArguments(dir)
                config.createsNewApplicationInstance = true
                ws.openApplication(at: app, configuration: config, completionHandler: quit)
            }
            return
        }
        finish()
    }

    // No app ID means "Other App…": let the user pick any app.
    private func openFolder(_ dir: String, appID: String?) {
        if let appID {
            open(dir, withAppAt: NSWorkspace.shared.urlForApplication(withBundleIdentifier: appID))
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        let openFormat = NSLocalizedString("Open “%@” with:", comment: "")
        panel.message = String(format: openFormat, (dir as NSString).lastPathComponent)
        panel.prompt = NSLocalizedString("Open", comment: "")
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        open(dir, withAppAt: panel.runModal() == .OK ? panel.url : nil)
    }

    private func open(_ dir: String, withAppAt app: URL?) {
        guard let app else { finish(); return }
        NSWorkspace.shared.open([URL(fileURLWithPath: dir, isDirectory: true)], withApplicationAt: app,
                                configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            DispatchQueue.main.async { self.finish() }
        }
    }

    private func newFile(in dir: String) {
        createFile(in: dir, suggested: "untitled.txt", ask: true)
    }

    // One click from the New File submenu: use the template's name, and if that name is taken,
    // pick the next free name the way Finder does (notes.md → notes 2.md).
    private func newFile(in dir: String, from template: FileTemplate) {
        createFile(in: dir, suggested: unusedFilename(template.filename, in: dir), ask: false)
    }

    private func createFile(in dir: String, suggested: String, ask: Bool) {
        var name = suggested
        var saveAsTemplate = false
        var problem: String?
        while true {
            if ask || problem != nil {
                let inFormat = NSLocalizedString("In: %@", comment: "")
                let inString = String(format: inFormat, (dir as NSString).abbreviatingWithTildeInPath)
                let info = (problem.map { $0 + "\n\n" } ?? "") + inString
                guard let options = askFileName(info: info, suggested: name,
                                                saveAsTemplate: saveAsTemplate) else { return }
                name = options.name.trimmingCharacters(in: .whitespacesAndNewlines)
                saveAsTemplate = options.saveAsTemplate
            }
            let full = (dir as NSString).appendingPathComponent(name)
            if !isValidFilename(name) {
                problem = NSLocalizedString("⚠️ That isn't a valid file name.", comment: "")
                continue
            }
            do {
                // A separate existence check cannot prevent another process from creating the same path.
                try Data().write(to: URL(fileURLWithPath: full), options: .withoutOverwriting)
                if saveAsTemplate { saveFileTemplate(filename: name) }
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: full)])
                return
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                let existsFormat = NSLocalizedString("⚠️ \"%@\" already exists.", comment: "")
                problem = String(format: existsFormat, name)
            } catch {
                problem = NSLocalizedString("⚠️ Couldn't create the file here (no permission?).", comment: "")
            }
        }
    }

    // Finder-style duplicate names: "notes.md" → "notes 2.md", "notes 3.md", …
    private func unusedFilename(_ filename: String, in dir: String) -> String {
        let ns = filename as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        // Unlike fileExists, attributesOfItem doesn't follow symlinks, so a broken link still counts as taken.
        func taken(_ name: String) -> Bool {
            (try? FileManager.default.attributesOfItem(atPath: (dir as NSString).appendingPathComponent(name))) != nil
        }
        var candidate = filename
        var n = 2
        while taken(candidate) {
            candidate = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            n += 1
        }
        return candidate
    }

    private struct NewFileOptions {
        var name: String
        var saveAsTemplate: Bool
    }

    private func askFileName(info: String, suggested: String, saveAsTemplate: Bool) -> NewFileOptions? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("New File", comment: "")
        alert.informativeText = info
        alert.addButton(withTitle: NSLocalizedString("Create", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        let field = NSTextField(frame: .zero)
        field.stringValue = suggested
        field.placeholderString = "name.ext"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 320).isActive = true
        field.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let saveBox = NSButton(checkboxWithTitle: NSLocalizedString("Save as template", comment: ""), target: nil, action: nil)
        saveBox.state = saveAsTemplate ? .on : .off

        let stack = NSStackView(views: [field, saveBox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(12, after: field)
        stack.frame = NSRect(origin: .zero, size: stack.fittingSize)
        alert.accessoryView = stack
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return NewFileOptions(name: field.stringValue, saveAsTemplate: saveBox.state == .on)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
