import Cocoa
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var handledURL = false

    func application(_ application: NSApplication, open urls: [URL]) {
        handledURL = true
        for url in urls {
            guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let path = c.queryItems?.first(where: { $0.name == "path" })?.value else { continue }
            switch c.host {
            case "newfile": newFile(in: folder(for: path))
            case "terminal": openTerminal(at: folder(for: path)); return
            case "openwith":
                openFolder(folder(for: path), appID: c.queryItems?.first(where: { $0.name == "app" })?.value)
                return
            case "up": goUp(from: path)
            default: break
            }
        }
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !self.handledURL else { return }
            NSApp.activate(ignoringOtherApps: true)
            let a = NSAlert()
            a.messageText = "Finder Menu is installed"
            a.informativeText = "Right-click inside any Finder folder to use New File…, Open Terminal Here, Open Folder With, Copy Path and Go to Parent Folder."
            a.runModal()
            NSApp.terminate(nil)
        }
    }

    private func folder(for path: String) -> String {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue ? path : (path as NSString).deletingLastPathComponent
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
                    if POSIX path of (target of w as alias) is \(lit(dir + "/")) then
                        set target of w to dest
                        return
                    end if
                end try
            end repeat
            if (count of Finder windows) > 0 then set target of front Finder window to dest
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error { NSLog("Finder Menu go-up failed: \(error)") }
    }

    private func openTerminal(at dir: String) {
        let ws = NSWorkspace.shared
        open(dir, withAppAt: ws.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")
                ?? ws.urlForApplication(withBundleIdentifier: "com.apple.Terminal"))
    }

    // No app ID means "Other App…": let the user pick any app.
    private func openFolder(_ dir: String, appID: String?) {
        if let appID {
            open(dir, withAppAt: NSWorkspace.shared.urlForApplication(withBundleIdentifier: appID))
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.message = "Open “\((dir as NSString).lastPathComponent)” with:"
        panel.prompt = "Open"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        open(dir, withAppAt: panel.runModal() == .OK ? panel.url : nil)
    }

    private func open(_ dir: String, withAppAt app: URL?) {
        guard let app else { NSApp.terminate(nil); return }
        NSWorkspace.shared.open([URL(fileURLWithPath: dir, isDirectory: true)], withApplicationAt: app,
                                configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private func newFile(in dir: String) {
        var name = "untitled.txt"
        var problem: String?
        while true {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "New File"
            alert.informativeText = (problem.map { $0 + "\n\n" } ?? "") + "In: " + (dir as NSString).abbreviatingWithTildeInPath
            alert.addButton(withTitle: "Create")
            alert.addButton(withTitle: "Cancel")
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
            field.stringValue = name
            field.placeholderString = "name.ext"
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else { return }

            name = field.stringValue.trimmingCharacters(in: .whitespaces)
            let full = (dir as NSString).appendingPathComponent(name)
            if name.isEmpty || name.contains("/") || name == "." || name == ".." {
                problem = "⚠️ That isn't a valid file name."
            } else if FileManager.default.fileExists(atPath: full) {
                problem = "⚠️ \"\(name)\" already exists."
            } else if !FileManager.default.createFile(atPath: full, contents: nil) {
                problem = "⚠️ Couldn't create the file here (no permission?)."
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: full)])
                return
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
