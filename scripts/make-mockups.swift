// Renders the README mockups to docs/images. docs/mockups/mockups.html lays out each scene in HTML and
// CSS; this script fills in the real SF Symbols, app and file icons, then saves every scene in light and
// dark at 2x. Editors that aren't installed get a generic app icon.
// Usage: swift scripts/make-mockups.swift
import AppKit
import UniformTypeIdentifiers
import WebKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let docs = root.appendingPathComponent("docs")
let scenes = ["menu", "templates", "settings"]

// Draws an image at 3x into a PNG data URL, so it stays sharp in a 2x render.
func dataURL(_ image: NSImage, size: NSSize) -> String {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int((size.width * 3).rounded(.up)),
                               pixelsHigh: Int((size.height * 3).rounded(.up)), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return "data:image/png;base64," + rep.representation(using: .png, properties: [:])!.base64EncodedString()
}

let weights: [String: NSFont.Weight] = ["regular": .regular, "medium": .medium, "semibold": .semibold, "bold": .bold]

// The icons a scene asked for, keyed the way mockups.html looks them up. Symbols are drawn black and
// used as masks, so the page can color them.
func icons(for requests: [[String: Any]]) -> [String: [String: Any]] {
    var result: [String: [String: Any]] = [:]
    let iconSize = NSSize(width: 16, height: 16)
    for request in requests {
        if let name = request["symbol"] as? String {
            let size = request["size"] as? Double ?? 13, weight = request["weight"] as? String ?? "regular"
            let key = "\(name)|\(Int(size))|\(weight)"
            guard result[key] == nil, let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: size, weight: weights[weight] ?? .regular)) else { continue }
            result[key] = ["url": dataURL(image, size: image.size), "width": image.size.width, "height": image.size.height]
        } else if let id = request["app"] as? String {
            let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            let image = app.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application)
            result[id] = ["url": dataURL(image, size: iconSize)]
        } else if let type = request["type"] as? String {
            result[type] = ["url": dataURL(NSWorkspace.shared.icon(for: UTType(type) ?? .data), size: iconSize)]
        }
    }
    return result
}

// Exactly 2x pixels for the scene's size in points. On a Retina screen the snapshot already is.
func png(_ image: NSImage, width: Double, height: Double) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * 2), pixelsHigh: Int(height * 2),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

final class Loader: NSObject, WKNavigationDelegate {
    var loaded: CheckedContinuation<Void, Never>?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded?.resume()
        loaded = nil
    }
}

@MainActor
func render() async throws {
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1600, height: 1200))
    web.setValue(false, forKey: "drawsBackground") // transparent around the windows and menus
    // WebKit only paints views that are in a window, so keep one offscreen.
    let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1600, height: 1200),
                          styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = web
    window.orderFrontRegardless()
    let loader = Loader()
    web.navigationDelegate = loader
    await withCheckedContinuation { continuation in
        loader.loaded = continuation
        web.loadFileURL(docs.appendingPathComponent("mockups/mockups.html"), allowingReadAccessTo: docs)
    }

    try FileManager.default.createDirectory(at: docs.appendingPathComponent("images"), withIntermediateDirectories: true)
    for scene in scenes {
        for theme in ["light", "dark"] {
            let requests = try await web.callAsyncJavaScript("return FM.show(scene, theme)",
                                                              arguments: ["scene": scene, "theme": theme],
                                                              contentWorld: .page) as! [[String: Any]]
            let size = try await web.callAsyncJavaScript("return await FM.provide(icons)",
                                                          arguments: ["icons": icons(for: requests)],
                                                          contentWorld: .page) as! [String: Any]
            let width = size["width"] as! Double, height = size["height"] as! Double
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: width, height: height)
            let image = try await web.takeSnapshot(configuration: config)
            let path = "docs/images/\(scene)-\(theme).png"
            try png(image, width: width, height: height).write(to: root.appendingPathComponent(path))
            print(path)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
Task { @MainActor in
    do {
        try await render()
        exit(0)
    } catch {
        print("Couldn't render the mockups: \(error)")
        exit(1)
    }
}
app.run()
