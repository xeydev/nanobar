import AppKit
import SwiftUI
import Monitors
import Widgets

// MARK: - SettingsWindowController

/// Owns the NanoBar Settings window. Call ``open()`` to show it; it auto-creates
/// on first use. The window is not recreated on repeated opens — the same instance
/// is shown/ordered-front, preserving any in-progress edits.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {}

    // MARK: - Public interface

    func open() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = makeWindow()
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    // MARK: - Private

    private func makeWindow() -> NSWindow {
        let content = NSHostingController(rootView: SettingsView())
        let win = NSWindow(contentViewController: content)
        win.title = "NanoBar Settings"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 680, height: 540))
        win.minSize = NSSize(width: 560, height: 420)
        win.center()
        win.delegate = self
        win.isReleasedWhenClosed = false
        return win
    }
}
