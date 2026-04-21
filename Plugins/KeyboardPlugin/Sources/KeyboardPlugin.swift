import Carbon
import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - State

@MainActor
private final class KeyboardState: ObservableObject, @unchecked Sendable {
    @Published var layout: String = "US"
    private var updateTask: Task<Void, Never>?

    init() {
        layout = currentLayout()
        // passRetained: CF holds a strong ref so the callback can never fire with a dead pointer.
        // Balanced by release() in deinit after removing the observer.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passRetained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let state = Unmanaged<KeyboardState>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in state.scheduleUpdate() }
            },
            kTISNotifySelectedKeyboardInputSourceChanged,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        updateTask?.cancel()
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDistributedCenter(),
            ptr,
            CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged),
            nil
        )
        // Release the retain we added in init.
        Unmanaged<KeyboardState>.fromOpaque(ptr).release()
    }

    // TIS notifications can fire multiple times per source change, and TIS needs ~50ms to
    // settle before the new source is readable. Debounce: cancel previous task, wait 50ms.
    func scheduleUpdate() {
        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            let new = currentLayout()
            if new != layout { layout = new }
        }
    }

    private func currentLayout() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return "US" }
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        return shortCode(for: name)
    }

    private func shortCode(for name: String) -> String {
        if name.contains("Dvorak")  { return "DV" }
        if name.contains("U.S.")    { return "US" }
        if name.contains("Russian") { return "RU" }
        if name.contains("Korean")  { return "한" }
        if name.contains("ABC")     { return "US" }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - View

private struct KeyboardWidgetView: View {
    @StateObject private var state = KeyboardState()
    let color: Color
    @State private var wiggle = false

    var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            Image(systemName: "keyboard.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 13)
                .foregroundStyle(color)
                .symbolEffect(.bounce, options: .nonRepeating, value: wiggle)
            Text(state.layout)
                .font(.system(size: Theme.labelSize, weight: .semibold))
                .foregroundStyle(Theme.labelColor)
                .lineLimit(1)
                .stableMinWidth()
        }
        .glassPill()
        .onChange(of: state.layout) { wiggle.toggle() }
    }
}

// MARK: - Factory

private final class KeyboardWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "keyboard" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        let color = Theme.color(hex: config["color"]) ?? Theme.keyboardColor
        return NanoBarViewBox(AnyView(KeyboardWidgetView(color: color)))
    }
}

// MARK: - Entry point

@objc(KeyboardPlugin)
public final class KeyboardPlugin: NSObject, NanoBarPluginEntry {
    public var pluginID: String { "keyboard" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(KeyboardWidgetFactory(config: config))
    }
}
