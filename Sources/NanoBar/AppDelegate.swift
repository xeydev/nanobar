import AppKit
import Carbon
import Widgets
import Monitors

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var barPanels: [BarPanel] = []
    private var mouseMonitors: [Any] = []
    private var fullscreenObservers: [Any] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        ConfigLoader.shared.loadOrCreate()
        ConfigLoader.shared.onReload = { [weak self] in self?.reinit() }
        reinit()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        installMenuBarCarbonHandler()
        installMouseMonitors()
        installFullscreenObservers()
    }

    // MARK: - Reinit

    /// Called on first launch and on every successful config reload.
    /// Tears down panels and widget registry, then rebuilds from current config.
    private func reinit() {
        barPanels.forEach { $0.close() }
        barPanels.removeAll()

        let config = ConfigLoader.shared.config
        WidgetRegistry.shared.clear()
        PluginLoader.shared.loadPlugins(config: config, registry: WidgetRegistry.shared)

        setupBars()
    }

    // MARK: - Bar setup

    private func setupBars() {
        for (index, screen) in NSScreen.screens.enumerated() {
            let panel = BarPanel(screen: screen, monitorID: index + 1)
            panel.orderFront(nil)
            barPanels.append(panel)
        }
        checkFullscreenState()
    }

    @objc private func screensChanged() {
        barPanels.forEach { $0.close() }
        barPanels.removeAll()
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
                let shown    = GetEventKind(event) == UInt32(kEventMenuBarShown)
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

    // MARK: - Fullscreen detection

    private func installFullscreenObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        let handler: @Sendable (Notification) -> Void = { [weak self] _ in
            DispatchQueue.main.async { self?.checkFullscreenState() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self?.checkFullscreenState() }
        }
        fullscreenObservers = [
            ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,      object: nil, queue: nil, using: handler),
            ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification,    object: nil, queue: nil, using: handler),
            ws.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification,  object: nil, queue: nil, using: handler),
        ]
    }

    private func checkFullscreenState() {
        for panel in barPanels {
            panel.setFullscreenHidden(screenHasFullscreenWindow(panel.associatedScreen))
        }
    }

    private func screenHasFullscreenWindow(_ screen: NSScreen) -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary else { continue }
            var cgRect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDict, &cgRect) else { continue }
            let cocoaRect = CGRect(x: cgRect.minX, y: primaryH - cgRect.maxY, width: cgRect.width, height: cgRect.height)
            if cocoaRect == screen.frame { return true }
        }
        return false
    }

    // MARK: - Mouse pass-through

    private func installMouseMonitors() {
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.syncMousePassThrough() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] event in
            self?.syncMousePassThrough(); return event
        }) {
            mouseMonitors.append(local)
        }
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
