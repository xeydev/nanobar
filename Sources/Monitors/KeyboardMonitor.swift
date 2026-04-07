import Foundation
import Carbon

/// Push-based keyboard layout monitor. Zero polling.
public final class KeyboardMonitor: @unchecked Sendable {
    public static let shared = KeyboardMonitor()

    private let broadcaster = MonitorBroadcaster<String>()

    public func register(_ observer: @escaping @MainActor (String) -> Void) {
        broadcaster.register(observer)
    }

    private init() {}

    public func start() {
        notifyCurrentLayout()
        // kTISNotifySelectedKeyboardInputSourceChanged is the Carbon-native notification
        // that TIS posts *after* it finishes updating, so no delay is needed.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<KeyboardMonitor>.fromOpaque(observer)
                    .takeUnretainedValue()
                    .notifyCurrentLayout()
            },
            kTISNotifySelectedKeyboardInputSourceChanged,
            nil,
            .deliverImmediately
        )
    }

    private func notifyCurrentLayout() {
        broadcaster.notify(currentLayout())
    }

    private func currentLayout() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return "US" }
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        return shortCode(for: name)
    }

    private func shortCode(for name: String) -> String {
        if name.contains("Dvorak") { return "DV" }
        if name.contains("U.S.")   { return "US" }
        if name.contains("Russian") { return "RU" }
        if name.contains("Korean") { return "한" }
        if name.contains("ABC")    { return "US" }
        return String(name.prefix(2)).uppercased()
    }
}
