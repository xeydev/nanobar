import AppKit
import Carbon
import Widgets
import Monitors

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var barPanels: [BarPanel] = []
    private var mouseMonitors: [Any] = []
    private var mouseSyncPending = false
    private var fullscreenObservers: [Any] = []
    private var fullscreenCheckWork: DispatchWorkItem?

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
                Task { @MainActor in delegate.handleMenuBarVisibility(visible: shown) }
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
            Task { @MainActor [weak self] in self?.scheduleFullscreenCheck() }
        }
        fullscreenObservers = [
            ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,      object: nil, queue: nil, using: handler),
            ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification,    object: nil, queue: nil, using: handler),
            ws.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification,  object: nil, queue: nil, using: handler),
        ]
    }

    private func scheduleFullscreenCheck() {
        fullscreenCheckWork?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.checkFullscreenState() }
        fullscreenCheckWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    private func checkFullscreenState() {
        // Snapshot main-thread data, then do the expensive window list query off-main.
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let targets = barPanels.map { (panel: $0, sf: $0.associatedScreen.frame) }
        Task(priority: .userInitiated) {
            let results = await Task.detached(priority: .userInitiated) {
                targets.map { (panel, sf) in
                    (panel, AppDelegate.screenHasFullscreenWindow(sf: sf, primaryH: primaryH))
                }
            }.value
            for (panel, hidden) in results { panel.setFullscreenHidden(hidden) }
        }
    }

    nonisolated private static func screenHasFullscreenWindow(sf: CGRect, primaryH: CGFloat) -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary else { continue }
            var cgRect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDict, &cgRect) else { continue }
            let cocoaRect = CGRect(x: cgRect.minX, y: primaryH - cgRect.maxY, width: cgRect.width, height: cgRect.height)
            let coversScreen = layer <= 0
                && cocoaRect.width  == sf.width
                && cocoaRect.minX   == sf.minX
                && cocoaRect.minY   == sf.minY
                && cocoaRect.height >= sf.height - 50
            if coversScreen { return true }
        }
        return false
    }

    // MARK: - Mouse pass-through

    private func installMouseMonitors() {
        // Global monitors may fire off the main thread; hop to @MainActor before touching state.
        let hop: @Sendable (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleMouseSync() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: hop) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] event in
            Task { @MainActor [weak self] in self?.scheduleMouseSync() }
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    /// Coalesces bursts of mouseMoved events: at most one syncMousePassThrough per runloop turn.
    private func scheduleMouseSync() {
        guard !mouseSyncPending else { return }
        mouseSyncPending = true
        // DispatchQueue.main.async defers to the next RunLoop iteration, which is required for
        // coalescing: multiple mouseMoved events within the same turn all see pending=true and
        // return early; the deferred block runs once after they have all been processed.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.mouseSyncPending = false
                self.syncMousePassThrough()
            }
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
