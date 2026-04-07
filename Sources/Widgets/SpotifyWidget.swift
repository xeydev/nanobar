import AppKit
import Monitors

private let symbolWidth: CGFloat = 12

@MainActor
public final class SpotifyWidget: BarWidget {
    public let view: NSView = SpotifyView()
    private var sv: SpotifyView { view as! SpotifyView }

    static let maxLabelWidth: CGFloat = 180

    public var intrinsicWidth: CGFloat {
        guard let title = sv.info.title, !title.isEmpty else { return 0 }
        let textWidth = min(sv.cachedTextWidth, Self.maxLabelWidth)
        return Theme.itemPadBg * 2 + Theme.iconPadLeft + symbolWidth + Theme.iconPadRight
             + Theme.labelPadLeft + textWidth + Theme.labelPadRight
    }

    public func place(at origin: CGPoint, height: CGFloat) {
        view.frame = CGRect(x: origin.x, y: origin.y, width: intrinsicWidth, height: height)
        if let layer = view.layer {
            layer.shadowPath = CGPath(
                roundedRect: CGRect(origin: .zero, size: CGSize(width: intrinsicWidth, height: height)),
                cornerWidth: Theme.itemCorner, cornerHeight: Theme.itemCorner, transform: nil
            )
        }
        sv.labelWidth = intrinsicWidth == 0 ? 0
            : intrinsicWidth - Theme.itemPadBg * 2 - Theme.iconPadLeft - symbolWidth - Theme.iconPadRight
              - Theme.labelPadLeft - Theme.labelPadRight
    }

    public func update(info: NowPlayingInfo) {
        sv.info = info
    }
}

private final class SpotifyView: BarItemView {
    var info = NowPlayingInfo(title: nil, artist: nil, isPlaying: false) {
        didSet { resetScroll() }
    }

    var labelWidth: CGFloat = SpotifyWidget.maxLabelWidth {
        didSet { guard labelWidth != oldValue else { return }; resetScroll() }
    }

    var fullText: String {
        var t = info.title ?? ""
        if let artist = info.artist, !artist.isEmpty { t += " — " + artist }
        return t
    }

    // Cached on each resetScroll — avoids remeasuring in tick() at 60fps
    private(set) var cachedTextWidth: CGFloat = 0

    // MARK: Scroll

    private var scrollOffset: CGFloat = 0
    private var scrollTimer: DispatchSourceTimer?

    private static let scrollSpeed: CGFloat = 40   // pts/sec
    private static let fps:         Double   = 60
    private static let gap:         CGFloat  = 50  // space between loop repetitions
    private static let fadeWidth:   CGFloat  = 14

    private static let textFont: NSFont =
        NSFont(name: "SF Pro Semibold", size: Theme.labelSize)
        ?? NSFont.systemFont(ofSize: Theme.labelSize, weight: .semibold)

    private func resetScroll() {
        stopTimer()
        scrollOffset = 0
        cachedTextWidth = measureLabel(fullText)
        needsDisplay = true
        if cachedTextWidth > labelWidth {
            // Brief pause so the new title is readable before it starts moving
            let t = DispatchSource.makeTimerSource(queue: .main)
            t.schedule(deadline: .now() + 1.2, repeating: 1.0 / Self.fps)
            t.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.tick() } }
            t.resume()
            scrollTimer = t
        }
    }

    private func stopTimer() {
        scrollTimer?.cancel()
        scrollTimer = nil
    }

    private func tick() {
        guard cachedTextWidth > labelWidth else {
            stopTimer(); scrollOffset = 0; needsDisplay = true; return
        }
        scrollOffset += CGFloat(Self.scrollSpeed / Self.fps)
        let period = cachedTextWidth + Self.gap
        if scrollOffset >= period { scrollOffset -= period }
        needsDisplay = true
    }

    override func removeFromSuperview() {
        stopTimer()
        super.removeFromSuperview()
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let title = info.title, !title.isEmpty else { return }
        drawItemBackground()

        var x = Theme.itemPadBg + Theme.iconPadLeft
        let accentColor = NSColor(cgColor: info.isPlaying ? Theme.spotifyActive : Theme.spotifyPaused)!
        let symbol = info.isPlaying ? "play.fill" : "pause.fill"
        let iw = drawSymbol(symbol, color: accentColor, size: Theme.iconSize - 2, at: CGPoint(x: x, y: 0))
        x += iw + Theme.iconPadRight + Theme.labelPadLeft

        let text = fullText
        let textW = cachedTextWidth
        let clipW = min(textW, labelWidth)
        let isScrolling = textW > labelWidth

        let attrStr = NSAttributedString(string: text, attributes: [
            .font: Self.textFont,
            .foregroundColor: NSColor(cgColor: Theme.labelColor)!
        ])
        let textY = (bounds.height - attrStr.size().height) / 2

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.clip(to: CGRect(x: x, y: 0, width: clipW, height: bounds.height))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)

        let drawX = x - scrollOffset
        attrStr.draw(at: CGPoint(x: drawX, y: textY))
        if isScrolling {
            attrStr.draw(at: CGPoint(x: drawX + textW + Self.gap, y: textY))

            ctx.setBlendMode(.destinationIn)
            let fw = min(Self.fadeWidth, clipW * 0.25)
            let colors = [CGColor(gray: 0, alpha: 0),
                          CGColor(gray: 0, alpha: 1),
                          CGColor(gray: 0, alpha: 1),
                          CGColor(gray: 0, alpha: 0)] as CFArray
            let locs: [CGFloat] = [0, fw / clipW, 1 - fw / clipW, 1]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(),
                                      colors: colors, locations: locs)!
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: x, y: 0),
                                   end:   CGPoint(x: x + clipW, y: 0),
                                   options: [])
        }

        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
}
