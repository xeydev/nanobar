import AppKit
import QuartzCore
import AeroSpaceClient

/// Renders all AeroSpace workspace groups on the left side of the bar.
@MainActor
public final class WorkspaceBar {
    public let layer: CALayer = CALayer()
    private var workspaceLayers: [String: WorkspaceGroupLayer] = [:]
    private var states: [WorkspaceState] = []
    private var maxWidth: CGFloat = 0
    private var height: CGFloat = 30

    public init() {
        layer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
    }

    public func update(states: [WorkspaceState]) {
        self.states = states
        relayout()
    }

    public func place(at origin: CGPoint, maxWidth: CGFloat, height: CGFloat) {
        self.maxWidth = maxWidth
        self.height = height
        layer.frame = CGRect(x: origin.x, y: origin.y, width: maxWidth, height: height)
        relayout()
    }

    private func relayout() {
        var x: CGFloat = 0
        var usedKeys = Set<String>()

        for state in states {
            // Only show non-empty workspaces (or focused one even if empty)
            guard !state.windows.isEmpty || state.isFocused else { continue }

            let groupLayer: WorkspaceGroupLayer
            if let existing = workspaceLayers[state.id] {
                groupLayer = existing
            } else {
                let gl = WorkspaceGroupLayer()
                workspaceLayers[state.id] = gl
                layer.addSublayer(gl)
                groupLayer = gl
            }
            usedKeys.insert(state.id)

            groupLayer.update(state: state)
            let w = groupLayer.preferredWidth
            groupLayer.frame = CGRect(x: x, y: 0, width: w, height: height)
            groupLayer.setNeedsDisplay()
            x += w + Theme.itemGap
        }

        // Remove stale layers
        let toRemove = workspaceLayers.keys.filter { !usedKeys.contains($0) }
        for key in toRemove {
            workspaceLayers[key]?.removeFromSuperlayer()
            workspaceLayers.removeValue(forKey: key)
        }
    }
}

// MARK: - WorkspaceGroupLayer

private final class WorkspaceGroupLayer: CALayer {
    private var state: WorkspaceState = WorkspaceState(id: "", isFocused: false, windows: [], monitorID: 1)
    private var iconLayers: [CALayer] = []

    var preferredWidth: CGFloat {
        let labelW = measureText(state.id, font: Theme.labelFont) + Theme.iconPadLeft + Theme.iconPadRight
        let iconsW = state.windows.isEmpty ? 0 : CGFloat(min(state.windows.count, 8)) * (Theme.iconSize + 4)
        return labelW + iconsW + Theme.labelPadLeft + Theme.labelPadRight + Theme.itemPadBg * 2
    }

    override init() { super.init(); drawsAsynchronously = true }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    func update(state: WorkspaceState) {
        self.state = state
    }

    override func draw(in ctx: CGContext) {
        ctx.drawItemBackground(in: bounds, focused: state.isFocused)
        let baseline: CGFloat = (bounds.height - Theme.iconSize) / 2 + 2
        var x: CGFloat = Theme.itemPadBg + Theme.iconPadLeft

        // Workspace label
        let labelColor = state.isFocused ? Theme.labelColor : Theme.grey
        x += ctx.drawText(state.id, font: Theme.labelFont, color: labelColor, at: CGPoint(x: x, y: baseline))
        x += Theme.iconPadRight

        // App icons (up to 8)
        let visibleWindows = Array(state.windows.prefix(8))
        for window in visibleWindows {
            let (glyph, color) = AppIconMap.lookup(appName: window.appName)
            x += ctx.drawText(glyph, font: Theme.appIconFont, color: color, at: CGPoint(x: x, y: baseline))
            x += 4
        }
    }
}
