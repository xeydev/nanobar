import AppKit
import Carbon
import Combine
import Widgets
import Monitors
import AeroSpaceClient

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var barPanels: [BarPanel] = []
    private let barState = BarState()
    private var globalMouseMonitor: Any?
    private var hoverCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupBars()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        ClockMonitor.shared.start()
        BatteryMonitor.shared.start()
        VolumeMonitor.shared.start()
        KeyboardMonitor.shared.start()
        MediaRemoteMonitor.shared.start()
        AeroSpaceMonitor.shared.start()

        installMenuBarCarbonHandler()
        installMousePassThrough()
    }

    private func setupBars() {
        barPanels.forEach { $0.close() }
        barPanels.removeAll()

        for (index, screen) in NSScreen.screens.enumerated() {
            let panel = BarPanel(screen: screen, monitorID: index + 1, state: barState)
            panel.orderFront(nil)
            barPanels.append(panel)
        }
    }

    @objc private func screensChanged() {
        setupBars()
    }

    // MARK: - Auto-hide menu bar detection via Carbon

    private func installMenuBarCarbonHandler() {
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuBarShown)),
            EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuBarHidden))
        ]
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let event, let userData else { return noErr }
                let shown = GetEventKind(event) == UInt32(kEventMenuBarShown)
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { delegate.handleMenuBarVisibility(visible: shown) }
                return noErr
            },
            specs.count,
            &specs,
            selfPtr,
            nil as UnsafeMutablePointer<EventHandlerRef?>?
        )
    }

    private func handleMenuBarVisibility(visible: Bool) {
        barPanels.forEach { $0.adjustForMenuBar(visible: visible) }
    }

    // MARK: - Mouse pass-through for non-interactive areas

    private func installMousePassThrough() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            DispatchQueue.main.async { self?.syncPanelMouseState() }
        }
        // When no interactive element is hovered, re-enable pass-through so
        // background clicks reach windows below.
        hoverCancellable = barState.$isHoveringInteractive.sink { [weak self] hovering in
            guard let self, !hovering else { return }
            self.barPanels.forEach { $0.ignoresMouseEvents = true }
        }
    }

    private func syncPanelMouseState() {
        let loc = NSEvent.mouseLocation
        for panel in barPanels {
            let shouldIgnore = !panel.frame.contains(loc)
            if panel.ignoresMouseEvents != shouldIgnore {
                panel.ignoresMouseEvents = shouldIgnore
            }
        }
    }
}
