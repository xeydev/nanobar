import AppKit
import QuartzCore
import Monitors

@MainActor
public final class SpotifyWidget: BarWidget {
    public let layer: CALayer = SpotifyLayer()
    private var info: NowPlayingInfo = NowPlayingInfo(title: nil, artist: nil, isPlaying: false)

    public var intrinsicWidth: CGFloat {
        guard let title = info.title, !title.isEmpty else { return 0 }
        let display = truncated(title)
        let lw = measureText(display, font: Theme.labelFont)
        let iw = Theme.iconSize + Theme.iconPadLeft + Theme.iconPadRight
        return iw + lw + Theme.labelPadLeft + Theme.labelPadRight + Theme.itemPadBg * 2
    }

    public func place(at origin: CGPoint, height: CGFloat) {
        layer.frame = CGRect(x: origin.x, y: origin.y, width: intrinsicWidth, height: height)
        layer.setNeedsDisplay()
    }

    public func update(info: NowPlayingInfo) {
        self.info = info
        (layer as? SpotifyLayer)?.info = info
        layer.setNeedsDisplay()
    }

    private func truncated(_ s: String) -> String {
        s.count > 40 ? String(s.prefix(40)) + "…" : s
    }
}

private final class SpotifyLayer: CALayer {
    var info = NowPlayingInfo(title: nil, artist: nil, isPlaying: false)

    override init() { super.init(); drawsAsynchronously = true }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(in ctx: CGContext) {
        guard let title = info.title, !title.isEmpty else { return }
        ctx.drawItemBackground(in: bounds)
        let display = title.count > 40 ? String(title.prefix(40)) + "…" : title
        let color = info.isPlaying ? Theme.spotifyActive : Theme.spotifyPaused
        let icon = info.isPlaying ? "" : ""  // play / pause glyphs
        let baseline: CGFloat = (bounds.height - Theme.iconSize) / 2 + 2
        var x: CGFloat = Theme.itemPadBg + Theme.iconPadLeft
        x += ctx.drawText(icon, font: Theme.iconFont, color: color, at: CGPoint(x: x, y: baseline))
        x += Theme.iconPadRight + Theme.labelPadLeft
        ctx.drawText(display, font: Theme.labelFont, color: Theme.labelColor, at: CGPoint(x: x, y: baseline))
    }
}
