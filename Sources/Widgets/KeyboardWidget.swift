import AppKit
import QuartzCore
import Monitors

@MainActor
public final class KeyboardWidget: BarWidget {
    public let layer: CALayer = KeyboardLayer()
    private var layout: String = "US"

    public var intrinsicWidth: CGFloat {
        let lw = measureText(layout, font: Theme.labelFont)
        let iw = Theme.iconSize + Theme.iconPadLeft + Theme.iconPadRight
        return iw + lw + Theme.labelPadLeft + Theme.labelPadRight + Theme.itemPadBg * 2
    }

    public func place(at origin: CGPoint, height: CGFloat) {
        layer.frame = CGRect(x: origin.x, y: origin.y, width: intrinsicWidth, height: height)
        layer.setNeedsDisplay()
    }

    public func update(layout: String) {
        self.layout = layout
        (layer as? KeyboardLayer)?.layout = layout
        layer.setNeedsDisplay()
    }
}

private final class KeyboardLayer: CALayer {
    var layout: String = "US"

    override init() { super.init(); drawsAsynchronously = true }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(in ctx: CGContext) {
        ctx.drawItemBackground(in: bounds)
        let icon = ""  // keyboard icon
        let baseline: CGFloat = (bounds.height - Theme.iconSize) / 2 + 2
        var x: CGFloat = Theme.itemPadBg + Theme.iconPadLeft
        x += ctx.drawText(icon, font: Theme.iconFont, color: Theme.keyboardColor, at: CGPoint(x: x, y: baseline))
        x += Theme.iconPadRight + Theme.labelPadLeft
        ctx.drawText(layout, font: Theme.labelFont, color: Theme.labelColor, at: CGPoint(x: x, y: baseline))
    }
}
