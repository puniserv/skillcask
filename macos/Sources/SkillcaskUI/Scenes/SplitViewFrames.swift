import Foundation

/// The main window's saved column layout, checked before the window opens. AppKit saves each `NavigationSplitView`
/// column's frame under `NSSplitView Subview Frames <window id>, <split view>` as `"x, y, width, height, collapsed,
/// hidden"` and restores it at launch. A sidebar collapsed at quit is saved with both flags `NO`, its last width, and
/// the next column at x 0, under it. The window always opens with its three columns shown (`MainWindow`), and on
/// macOS 26 that restored layout opened it with empty columns and hung it in a layout loop on a sidebar toggle until
/// it crashed. A layout whose visible columns overlap is never right for that window: dropping it lets SwiftUI lay
/// the columns out from their ideal widths again.
public enum SplitViewFrames {
    static let prefix = "NSSplitView Subview Frames "
    /// Columns that touch may differ by rounding.
    static let tolerance = 0.5

    /// Removes the main window's unsound layouts from `defaults` and returns the keys it removed, sorted. A layout
    /// from a domain the app cannot write (the arguments, the global domain) is not reported, so the caller does not
    /// discard the saved state on every launch for it.
    @discardableResult public static func repair(_ defaults: UserDefaults) -> [String] {
        unsoundKeys(defaults.dictionaryRepresentation())
            .filter { key in
                defaults.removeObject(forKey: key)
                return defaults.object(forKey: key) == nil
            }
    }

    /// After `repair` dropped a layout: removes the app's saved window state as well, which the report's fix also
    /// cleared, so the window cannot come back from it with the same columns. Nothing without a bundle identifier
    /// (`swift run`).
    public static func discardSavedState(bundle: Bundle = .main, fileManager: FileManager = .default) {
        guard let identifier = bundle.bundleIdentifier,
            let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
        else { return }
        try? fileManager.removeItem(at: library.appending(path: "Saved Application State/\(identifier).savedState"))
    }

    /// The keys of main-window layouts that do not parse or whose visible columns overlap, sorted; another
    /// window's layout and every other default are left alone.
    static func unsoundKeys(_ values: [String: Any]) -> [String] {
        values.compactMap { key, value in
            guard key.hasPrefix(prefix) else { return nil }
            let window = key.dropFirst(prefix.count).prefix { $0 != "," }
            guard Workspace.isMainScene(String(window)) else { return nil }
            return isSound(value) ? nil : key
        }
        .sorted()
    }

    /// Every frame parses, and no two visible columns overlap. Compared in order of x, not of the columns, so a
    /// right-to-left layout is judged the same way.
    static func isSound(_ value: Any) -> Bool {
        guard let lines = value as? [String] else { return false }
        let frames = lines.map(Frame.init(line:))
        guard frames.allSatisfy({ $0 != nil }) else { return false }
        let visible = frames.compactMap { $0 }.filter { !$0.collapsed && !$0.hidden }.sorted { $0.x < $1.x }
        return zip(visible, visible.dropFirst())
            .allSatisfy { previous, next in
                next.x + tolerance >= previous.x + previous.width
            }
    }

    /// One saved column: `"x, y, width, height, collapsed, hidden"` with `YES`/`NO` flags.
    struct Frame {
        var x: Double
        var width: Double
        var collapsed: Bool
        var hidden: Bool

        init?(line: String) {
            let fields = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count == 6 else { return nil }
            let numbers = fields[0..<4].compactMap(Double.init)
            guard numbers.count == 4, numbers.allSatisfy(\.isFinite), numbers[2] >= 0, numbers[3] >= 0,
                let collapsed = Self.flag(fields[4]), let hidden = Self.flag(fields[5])
            else { return nil }
            (x, width, self.collapsed, self.hidden) = (numbers[0], numbers[2], collapsed, hidden)
        }

        private static func flag(_ field: String) -> Bool? {
            switch field {
            case "YES": true
            case "NO": false
            default: nil
            }
        }
    }
}
