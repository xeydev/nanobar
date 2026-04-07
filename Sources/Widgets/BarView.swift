import AppKit
import QuartzCore
import Monitors
import AeroSpaceClient

/// Root NSView for one screen's bar. Manages layout of all widgets.
@MainActor
public final class BarView: NSView {
    // Right-side widgets (order = right to left when laying out)
    private let clockWidget    = ClockWidget()
    private let batteryWidget  = BatteryWidget()
    private let volumeWidget   = VolumeWidget()
    private let keyboardWidget = KeyboardWidget()
    private let spotifyWidget  = SpotifyWidget()

    // Left-side
    private let workspaceBar   = WorkspaceBar()

    private let isBuiltIn: Bool

    public init(frame: CGRect, screen: NSScreen) {
        self.isBuiltIn = screen.localizedName.lowercased().contains("built-in")
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)

        // Add all widget layers
        let sublayers: [CALayer] = [
            workspaceBar.layer,
            spotifyWidget.layer,
            clockWidget.layer,
            batteryWidget.layer,
            volumeWidget.layer,
            keyboardWidget.layer,
        ]
        sublayers.forEach { layer?.addSublayer($0) }

        // Wire up monitor callbacks
        ClockMonitor.shared.onChange = { [weak self] text in
            self?.clockWidget.update(text: text)
            self?.layoutWidgets()
        }
        BatteryMonitor.shared.onChange = { [weak self] info in
            self?.batteryWidget.update(info: info)
            self?.layoutWidgets()
        }
        VolumeMonitor.shared.onChange = { [weak self] volume in
            self?.volumeWidget.update(volume: volume)
            self?.layoutWidgets()
        }
        KeyboardMonitor.shared.onChange = { [weak self] layout in
            self?.keyboardWidget.update(layout: layout)
            self?.layoutWidgets()
        }
        MediaRemoteMonitor.shared.onChange = { [weak self] info in
            self?.spotifyWidget.update(info: info)
            self?.layoutWidgets()
        }
        AeroSpaceMonitor.shared.onChange = { [weak self] states in
            self?.workspaceBar.update(states: states)
            self?.layoutWidgets()
        }

        layoutWidgets()
    }

    required init?(coder: NSCoder) { fatalError() }

    public override var isFlipped: Bool { false }

    private func layoutWidgets() {
        let h = bounds.height

        // Right side: pack widgets right-to-left
        var rightX = bounds.width
        let rightWidgets: [any BarWidget] = [keyboardWidget, volumeWidget, batteryWidget, clockWidget, spotifyWidget]
        for widget in rightWidgets {
            let w = widget.intrinsicWidth
            guard w > 0 else { continue }
            rightX -= Theme.itemGap + w
            widget.place(at: CGPoint(x: rightX, y: 0), height: h)
        }

        // Left side: workspaces
        let notchOffset: CGFloat = isBuiltIn ? Theme.notchWidth : 0
        workspaceBar.place(at: CGPoint(x: 0, y: 0), maxWidth: rightX - Theme.itemGap - notchOffset, height: h)
    }

    public override func layout() {
        super.layout()
        layoutWidgets()
    }
}
