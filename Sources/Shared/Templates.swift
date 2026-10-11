import Foundation

// User-defined New File templates. Saved from the New File dialog ("Save as template");
// the extension only reads them to build the New File submenu, and the helper creates the
// file from the chosen id (the file name never travels in the findermenu:// URL).
struct FileTemplate: Equatable {
    var id = UUID().uuidString
    var filename: String
}

private let templatesKey = "FileTemplates"

var fileTemplates: [FileTemplate] {
    get {
        // Decode each entry on its own, so one malformed entry doesn't hide (and later overwrite) the rest.
        (settings.array(forKey: templatesKey) ?? []).compactMap { entry in
            guard let dict = entry as? [String: Any], let id = dict["id"] as? String,
                  let filename = dict["filename"] as? String, isValidFilename(filename) else { return nil }
            return FileTemplate(id: id, filename: filename)
        }
    }
    set {
        settings.set(newValue.map { ["id": $0.id, "filename": $0.filename] }, forKey: templatesKey)
    }
}

func fileTemplate(id: String) -> FileTemplate? {
    fileTemplates.first { $0.id == id }
}

// Saving a name that's already a template keeps the existing one.
func saveFileTemplate(filename: String) {
    guard isValidFilename(filename), !fileTemplates.contains(where: { $0.filename == filename }) else { return }
    fileTemplates.append(FileTemplate(filename: filename))
}

func removeFileTemplate(id: String) {
    fileTemplates = fileTemplates.filter { $0.id != id }
}

// The rules for any New File name, typed or saved as a template: no empty names, no path separators.
func isValidFilename(_ name: String) -> Bool {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return !name.isEmpty && !name.contains("/") && name != "." && name != ".."
}
