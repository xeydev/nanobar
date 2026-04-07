import Foundation
import Carbon

/// Push-based keyboard layout monitor. Zero polling.
public final class KeyboardMonitor: @unchecked Sendable {
    public static let shared = KeyboardMonitor()
    public var onChange: (@MainActor (String) -> Void)?

    private init() {}

    public func start() {
        // Initial read
        notifyCurrentLayout()

        // Push notification from macOS when input source changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name("AppleSelectedInputSourcesChangedNotification"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func inputSourceChanged() {
        notifyCurrentLayout()
    }

    private func notifyCurrentLayout() {
        let layout = currentLayout()
        let cb = onChange
        DispatchQueue.main.async { cb?(layout) }
    }

    private func currentLayout() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return "US" }
        guard let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return "US" }
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        return shortCode(for: name)
    }

    private func shortCode(for name: String) -> String {
        if name.contains("Dvorak")          { return "DV" }
        if name.contains("U.S.")            { return "US" }
        if name.contains("Russian")         { return "RU" }
        if name.contains("Korean")          { return "한" }
        if name.contains("ABC")             { return "US" }
        // Fallback: first 2 chars uppercase
        return String(name.prefix(2)).uppercased()
    }
}
