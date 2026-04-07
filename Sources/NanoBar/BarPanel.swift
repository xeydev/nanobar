import AppKit
import SwiftUI
import Widgets

@MainActor
final class BarPanel: NSPanel {
    private let associatedScreen: NSScreen
    private var menuBarVisible = false

    init(screen: NSScreen, monitorID: Int, state: BarState) {
        self.associatedScreen = screen
        let frame    = BarPanel.barFrame(for: screen)
        let isBuiltIn = screen.localizedName.lowercased().contains("built-in")
        let rootView = BarRootView(isBuiltIn: isBuiltIn, monitorID: monitorID)
            .environmentObject(state)
        let hosting  = NSHostingView(rootView: rootView)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)

        level                     = .statusBar
        collectionBehavior        = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        isOpaque                  = false
        backgroundColor           = .clear
        hasShadow                 = false
        ignoresMouseEvents        = false
        contentView               = hosting
    }

    func adjustForMenuBar(visible: Bool) {
        guard visible != menuBarVisible else { return }
        menuBarVisible = visible
        var target = BarPanel.barFrame(for: associatedScreen)
        if visible { target.origin.y = associatedScreen.frame.maxY }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Theme.menuBarAnimDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(target, display: true)
            animator().alphaValue = visible ? 0 : 1
        }
    }

    static func barFrame(for screen: NSScreen) -> CGRect {
        let sf = screen.frame
        return CGRect(
            x: sf.minX,
            y: sf.maxY - Theme.barHeight - Theme.barMargin * 2,
            width:  sf.width,
            height: Theme.barHeight + Theme.barMargin * 2
        )
    }
}
