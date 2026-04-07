import AppKit
import Widgets
import Monitors
import AeroSpaceClient

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var barPanels: [BarPanel] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register app icon font
        if let fontURL = Bundle.module.url(forResource: "sketchybar-app-font", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }

        // Hide from Dock and app switcher
        NSApp.setActivationPolicy(.accessory)

        setupBars()

        // React to display connect/disconnect
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Start all monitors
        ClockMonitor.shared.start()
        BatteryMonitor.shared.start()
        VolumeMonitor.shared.start()
        KeyboardMonitor.shared.start()
        MediaRemoteMonitor.shared.start()
        AeroSpaceMonitor.shared.start()
    }

    private func setupBars() {
        // Tear down existing
        barPanels.forEach { $0.close() }
        barPanels.removeAll()

        for screen in NSScreen.screens {
            let panel = BarPanel(screen: screen)
            panel.orderFront(nil)
            barPanels.append(panel)
        }
    }

    @objc private func screensChanged() {
        setupBars()
    }
}
