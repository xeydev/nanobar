import AppKit
import QuartzCore
import Monitors

@MainActor
public final class VolumeWidget: BarWidget {
    public let layer: CALayer = VolumeLayer()
    private var volume: Float = 0.5

    public var intrinsicWidth: CGFloat {
        let pct = Int(volume * 100)
        let lw = measureText("\(pct)%", font: Theme.labelFont)
        let iw = Theme.iconSize + Theme.iconPadLeft + Theme.iconPadRight
        return iw + lw + Theme.labelPadLeft + Theme.labelPadRight + Theme.itemPadBg * 2
    }

    public func place(at origin: CGPoint, height: CGFloat) {
        layer.frame = CGRect(x: origin.x, y: origin.y, width: intrinsicWidth, height: height)
        layer.setNeedsDisplay()
    }

    public func update(volume: Float) {
        self.volume = volume
        (layer as? VolumeLayer)?.volume = volume
        layer.setNeedsDisplay()
    }
}

private final class VolumeLayer: CALayer {
    var volume: Float = 0.5

    override init() { super.init(); drawsAsynchronously = true }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(in ctx: CGContext) {
        ctx.drawItemBackground(in: bounds)
        let pct = Int(volume * 100)
        let icon = volumeIcon(pct)
        let baseline: CGFloat = (bounds.height - Theme.iconSize) / 2 + 2
        var x: CGFloat = Theme.itemPadBg + Theme.iconPadLeft
        x += ctx.drawText(icon, font: Theme.iconFont, color: Theme.volumeColor, at: CGPoint(x: x, y: baseline))
        x += Theme.iconPadRight + Theme.labelPadLeft
        ctx.drawText("\(pct)%", font: Theme.labelFont, color: Theme.labelColor, at: CGPoint(x: x, y: baseline))
    }

    private func volumeIcon(_ pct: Int) -> String {
        if pct == 0  { return "" } // speaker.slash
        if pct < 25  { return "" } // speaker
        if pct < 50  { return "" } // speaker.wave.1
        if pct < 75  { return "" } // speaker.wave.2
        return ""                   // speaker.wave.3
    }
}
