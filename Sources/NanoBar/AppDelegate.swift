import AppKit
import Carbon
import Widgets
import Monitors
import AeroSpaceClient

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var barPanels: [BarPanel] = []
    private let barState = BarState()
    private var mouseMonitors: [Any] = []

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
        installMouseMonitors()
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

    // MARK: - Mouse pass-through

    // Toggles ignoresMouseEvents per-panel based on whether the cursor is over
    // an interactive region. Global monitor fires when events go to other apps
    // (ignoresMouseEvents = true). Local monitor fires when they come to us.
    private func installMouseMonitors() {
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.syncMousePassThrough() }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler)!
        let local  = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.syncMousePassThrough(); return event
        }!
        mouseMonitors = [global, local]
    }

    private func syncMousePassThrough() {
        let loc = NSEvent.mouseLocation
        for panel in barPanels {
            let windowPoint = panel.convertPoint(fromScreen: loc)
            let interactive = panel.frame.contains(loc)
                           && panel.contentView?.hitTest(windowPoint) != nil
            if panel.ignoresMouseEvents == interactive {
                panel.ignoresMouseEvents = !interactive
            }
        }
    }

}
