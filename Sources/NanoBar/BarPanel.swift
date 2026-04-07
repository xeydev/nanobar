import AppKit
import Widgets
import QuartzCore

/// A floating panel that renders the status bar for a single NSScreen.
@MainActor
final class BarPanel: NSPanel {
    private let barView: BarView
    private let associatedScreen: NSScreen

    init(screen: NSScreen) {
        self.associatedScreen = screen

        let frame = BarPanel.barFrame(for: screen)
        let view = BarView(frame: CGRect(origin: .zero, size: frame.size), screen: screen)
        self.barView = view

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Float above all normal windows, below system overlays
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false

        contentView = view
    }

    static func barFrame(for screen: NSScreen) -> CGRect {
        let sf = screen.frame
        let height: CGFloat = 30
        let margin: CGFloat = 8
        return CGRect(
            x: sf.minX + margin,
            y: sf.maxY - height - margin,
            width: sf.width - margin * 2,
            height: height
        )
    }

    static func isBuiltIn(_ screen: NSScreen) -> Bool {
        screen.localizedName.lowercased().contains("built-in") ||
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == CGMainDisplayID()
    }
}
