import AppKit
import QuartzCore
import Monitors

@MainActor
public final class BatteryWidget: BarWidget {
    public let layer: CALayer = BatteryLayer()
    private var info: BatteryInfo = BatteryInfo(percentage: 100, isCharging: false)

    public var intrinsicWidth: CGFloat {
        let lw = measureText("\(info.percentage)%", font: Theme.labelFont)
        let iw = Theme.iconSize + Theme.iconPadLeft + Theme.iconPadRight
        return iw + lw + Theme.labelPadLeft + Theme.labelPadRight + Theme.itemPadBg * 2
    }

    public func place(at origin: CGPoint, height: CGFloat) {
        layer.frame = CGRect(x: origin.x, y: origin.y, width: intrinsicWidth, height: height)
        layer.setNeedsDisplay()
    }

    public func update(info: BatteryInfo) {
        self.info = info
        (layer as? BatteryLayer)?.info = info
        layer.setNeedsDisplay()
    }
}

private final class BatteryLayer: CALayer {
    var info = BatteryInfo(percentage: 100, isCharging: false)

    override init() { super.init(); drawsAsynchronously = true }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(in ctx: CGContext) {
        ctx.drawItemBackground(in: bounds)
        let color = batteryColor(info.percentage, charging: info.isCharging)
        let icon = batteryIcon(info.percentage, charging: info.isCharging)
        let baseline: CGFloat = (bounds.height - Theme.iconSize) / 2 + 2
        var x: CGFloat = Theme.itemPadBg + Theme.iconPadLeft
        x += ctx.drawText(icon, font: Theme.iconFont, color: color, at: CGPoint(x: x, y: baseline))
        x += Theme.iconPadRight + Theme.labelPadLeft
        ctx.drawText("\(info.percentage)%", font: Theme.labelFont, color: Theme.labelColor, at: CGPoint(x: x, y: baseline))
    }

    private func batteryColor(_ pct: Int, charging: Bool) -> CGColor {
        if charging || pct > 60 { return Theme.batteryGreen }
        if pct > 40 { return Theme.batteryYellow }
        if pct > 20 { return Theme.batteryOrange }
        return Theme.batteryRed
    }

    private func batteryIcon(_ pct: Int, charging: Bool) -> String {
        if charging { return "" }  // battery.bolt
        if pct > 75 { return "" } // battery.100
        if pct > 50 { return "" } // battery.75
        if pct > 25 { return "" } // battery.50
        if pct > 10 { return "" } // battery.25
        return ""                  // battery.0
    }
}
