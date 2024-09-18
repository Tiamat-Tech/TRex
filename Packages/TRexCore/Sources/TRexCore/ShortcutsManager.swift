import AppKit
import Foundation
import ScriptingBridge

@objc protocol ShortcutsEvents {
    @objc optional var shortcuts: SBElementArray { get }
}

@objc protocol Shortcut {
    @objc optional var name: String { get }
    @objc optional func run(withInput: Any?) -> Any?
}

extension SBApplication: ShortcutsEvents {}
extension SBObject: Shortcut {}

public class ShortcutsManager: ObservableObject {
    static let shared = ShortcutsManager()
    var task: Process?
    var shortcutsURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
    var shellURL = URL(fileURLWithPath: "/bin/zsh")

    @Published public var shortcuts: [String] = []
    var currentShortcut: String {
        Preferences.shared.autoRunShortcut
    }

    lazy var shortcutInputPath: URL = {
        let directory = NSTemporaryDirectory()
        return NSURL.fileURL(withPathComponents: [directory, "shortcutInput"])!
    }()

    public init() {
        if #available(macOS 12, *) {
            getShortcuts()
        }
    }

    public func getShortcuts() {
        task = Process()
        task?.executableURL = shortcutsURL
        task?.arguments = ["list"]

        let pipe = Pipe()
        task?.standardOutput = pipe
        task?.launch()
        task?.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        shortcuts = output.components(separatedBy: .newlines).sorted()
    }

    public func runShortcut(inputText: String) {
        guard !currentShortcut.isEmpty else { return }
        try? inputText.write(toFile: shortcutInputPath.path, atomically: true, encoding: .utf8)
        task = Process()
        task?.executableURL = shortcutsURL
        task?.arguments = ["run", "\(currentShortcut)", "-i", "\(shortcutInputPath.path)"]

        task?.launch()
        task?.waitUntilExit()
//        guard let app: ShortcutsEvents? = SBApplication(bundleIdentifier: "com.apple.shortcuts.events") else {
//            print("Can't access Shortcuts app")
//            return
//        }
//        guard let shortcut = app?.shortcuts?.object(withName: currentShortcut) as? Shortcut else {
//            print("Shortcut doesn't exist")
//            return
//        }
//        _ = shortcut.run?(withInput: inputText)
    }

    public func viewCurrentShortcut() {
        guard !currentShortcut.isEmpty else { return }
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "open-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: currentShortcut),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    public func createShortcut() {
        NSWorkspace.shared.open(URL(string: "shortcuts://create-shortcut")!)
    }
}
