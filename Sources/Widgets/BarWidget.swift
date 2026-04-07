import AppKit
import QuartzCore

/// A single widget rendered as a CALayer.
/// All methods called on @MainActor.
@MainActor
public protocol BarWidget: AnyObject {
    var layer: CALayer { get }
    /// Width the widget wants to occupy (including bg padding on both sides)
    var intrinsicWidth: CGFloat { get }
    /// Called by layout engine to position the widget
    func place(at origin: CGPoint, height: CGFloat)
}

// MARK: - Helpers for drawing inside a widget layer

public extension CGContext {
    /// Draw a rounded-rect background + 1px border matching Theme.
    func drawItemBackground(in rect: CGRect, focused: Bool = false) {
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: Theme.itemCorner,
            cornerHeight: Theme.itemCorner,
            transform: nil
        )
        setFillColor(focused ? Theme.itemBgFocused : Theme.itemBg)
        addPath(path); fillPath()

        setStrokeColor(Theme.itemBorder)
        setLineWidth(1.0)
        addPath(path); strokePath()
    }

    /// Draw a string using Core Text, returns the line's width.
    @discardableResult
    func drawText(
        _ text: String,
        font: CTFont,
        color: CGColor,
        at point: CGPoint
    ) -> CGFloat {
        let attrs: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color
        ]
        let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)
        textPosition = point
        CTLineDraw(line, self)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
}

/// Measures text width without drawing.
public func measureText(_ text: String, font: CTFont) -> CGFloat {
    let attrs: [CFString: Any] = [kCTFontAttributeName: font]
    let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrStr)
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}
