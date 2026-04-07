@preconcurrency import CoreText
import CoreGraphics
import AppKit

/// Color and layout constants matching the existing SketchyBar pastel-on-near-black theme.
public enum Theme {
    // MARK: - Colors
    public static let barBg           = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let itemBg          = CGColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0.6)    // 0x99101010
    public static let itemBgFocused   = CGColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 0.93)   // 0xee222222
    public static let itemBorder      = CGColor(red: 0.165, green: 0.165, blue: 0.165, alpha: 1.0)    // 0xff2a2a2a
    public static let iconColor       = CGColor(red: 0.867, green: 0.714, blue: 0.949, alpha: 1.0)    // lavender
    public static let labelColor      = CGColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1.0)    // off-white
    public static let grey            = CGColor(red: 0.533, green: 0.533, blue: 0.533, alpha: 1.0)

    // Widget-specific accent colors
    public static let spotifyActive   = CGColor(red: 0.710, green: 0.918, blue: 0.843, alpha: 1.0)   // mint
    public static let spotifyPaused   = CGColor(red: 0.533, green: 0.533, blue: 0.533, alpha: 1.0)   // grey
    public static let volumeColor     = CGColor(red: 0.682, green: 0.776, blue: 0.910, alpha: 1.0)   // powder blue
    public static let calendarColor   = CGColor(red: 1.000, green: 0.702, blue: 0.757, alpha: 1.0)   // rose
    public static let keyboardColor   = CGColor(red: 0.867, green: 0.714, blue: 0.949, alpha: 1.0)   // lavender

    // Battery colors
    public static let batteryGreen    = CGColor(red: 0.710, green: 0.918, blue: 0.843, alpha: 1.0)
    public static let batteryYellow   = CGColor(red: 1.000, green: 0.961, blue: 0.729, alpha: 1.0)
    public static let batteryOrange   = CGColor(red: 1.000, green: 0.820, blue: 0.659, alpha: 1.0)
    public static let batteryRed      = CGColor(red: 1.000, green: 0.702, blue: 0.757, alpha: 1.0)

    // MARK: - Layout
    public static let barHeight:      CGFloat = 30
    public static let barMargin:      CGFloat = 8
    public static let itemCorner:     CGFloat = 12
    public static let barCorner:      CGFloat = 14
    public static let itemPadBg:      CGFloat = 3   // background padding left/right
    public static let iconPadLeft:    CGFloat = 12
    public static let iconPadRight:   CGFloat = 4
    public static let labelPadLeft:   CGFloat = 4
    public static let labelPadRight:  CGFloat = 12
    public static let itemGap:        CGFloat = 4   // gap between adjacent items
    public static let iconSize:       CGFloat = 15
    public static let labelSize:      CGFloat = 12
    public static let notchWidth:     CGFloat = 160 // reserved space around built-in display notch

    // MARK: - Fonts
    public static let iconFont  = CTFontCreateWithName("SF Pro" as CFString, iconSize, nil)
    public static let labelFont = CTFontCreateWithName("SF Pro Semibold" as CFString, labelSize, nil)
    public static let appIconFont = CTFontCreateWithName("sketchybar-app-font" as CFString, iconSize, nil)
}
