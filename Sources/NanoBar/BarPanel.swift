import AppKit
import SwiftUI
import Widgets
import Monitors

@MainActor
final class BarPanel: NSPanel {
    let associatedScreen: NSScreen
    private var menuBarVisible = false
    private var fullscreenHidden = false

    init(screen: NSScreen, monitorID: Int) {
        self.associatedScreen = screen
        let frame    = BarPanel.barFrame(for: screen)
        let isBuiltIn = screen.localizedName.lowercased().contains("built-in")
        let regionStore = InteractiveRegionStore()
        let rootView = BarRootView(isBuiltIn: isBuiltIn, monitorID: monitorID)
            .environmentObject(ConfigLoader.shared)
            .onPreferenceChange(InteractiveRegionKey.self) { rects in
                Task { @MainActor in
                    regionStore.rects = rects
                }
            }
        let hosting  = PassThroughHostingView(rootView: rootView, regionStore: regionStore)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Panel has a fixed frame — disable SwiftUI's per-frame sizeThatFits computation.
        // Without this, NSHostingView.layout() calls _sizeThatFits on every display cycle
        // which traverses the entire view graph (StackLayout, ViewThatFits, GeometryReaders).
        hosting.sizingOptions = []
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)

        level                       = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        collectionBehavior          = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        isOpaque                    = false
        backgroundColor             = .clear
        hasShadow                   = false
        // ignoresMouseEvents stays false (default) — panel stays in the
        // compositor's live compositing chain so glassEffect() samples live
        // desktop content. PassThroughHostingView.hitTest() handles per-pixel
        // pass-through for non-interactive areas.
        contentView                 = hosting
    }

    func adjustForMenuBar(visible: Bool) {
        guard visible != menuBarVisible else { return }
        menuBarVisible = visible
        guard !fullscreenHidden else { return }
        var target = BarPanel.barFrame(for: associatedScreen)
        if visible { target.origin.y = associatedScreen.frame.maxY }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Theme.menuBarAnimDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(target, display: true)
            animator().alphaValue = visible ? 0 : 1
        }
    }

    func setFullscreenHidden(_ hidden: Bool) {
        guard hidden != fullscreenHidden else { return }
        fullscreenHidden = hidden
        let targetAlpha: CGFloat = (hidden || menuBarVisible) ? 0 : 1
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Theme.menuBarAnimDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = targetAlpha
        }
    }

    static func barFrame(for screen: NSScreen) -> CGRect {
        let sf = screen.frame
        return CGRect(
            x: sf.minX,
            y: sf.maxY - Theme.barContainerHeight - Theme.shadowOverflow,
            width:  sf.width,
            height: Theme.barContainerHeight + Theme.shadowOverflow
        )
    }
}
