import AppKit
import QuartzCore

/// Displays current date/time: "Mon 07 Apr 14:30"
@MainActor
public final class ClockWidget: BarWidget {
    public let layer: CALayer = ClockLayer()
    private var text: String = ""

    public var intrinsicWidth: CGFloat {
        guard !text.isEmpty else { return 0 }
        let iw = measureText("", font: Theme.iconFont) + Theme.iconPadLeft + Theme.iconPadRight
        let lw = measureText(text, font: Theme.labelFont) + Theme.labelPadLeft + Theme.labelPadRight
        return iw + lw + Theme.itemPadBg * 2
    }

    public func place(at origin: CGPoint, height: CGFloat) {
        layer.frame = CGRect(x: origin.x, y: origin.y, width: intrinsicWidth, height: height)
        layer.setNeedsDisplay()
    }

    public func update(text: String) {
        self.text = text
        (layer as? ClockLayer)?.text = text
        layer.setNeedsDisplay()
    }
}

private final class ClockLayer: CALayer {
    var text: String = ""

    override init() { super.init(); drawsAsynchronously = true }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(in ctx: CGContext) {
        guard !text.isEmpty else { return }
        ctx.drawItemBackground(in: bounds)
        let icon = ""  // calendar SF symbol alternative: use Unicode or font glyph
        let baseline: CGFloat = (bounds.height - Theme.iconSize) / 2 + 2
        var x: CGFloat = Theme.itemPadBg + Theme.iconPadLeft
        x += ctx.drawText(icon, font: Theme.iconFont, color: Theme.calendarColor, at: CGPoint(x: x, y: baseline))
        x += Theme.iconPadRight + Theme.labelPadLeft
        ctx.drawText(text, font: Theme.labelFont, color: Theme.labelColor, at: CGPoint(x: x, y: baseline))
    }
}
