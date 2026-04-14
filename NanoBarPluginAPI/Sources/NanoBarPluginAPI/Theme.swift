import SwiftUI

public enum Theme {
    // MARK: - Colors (semantic — adapt to light/dark and system accent)
    public static let iconColor: Color     = Color(red: 0.867, green: 0.714, blue: 0.949) // lavender
    public static let labelColor: Color    = .primary                                  // white in dark, dark in light
    public static let grey: Color          = .secondary                                // dim text

    public static let spotifyActive: Color = Color(red: 0.710, green: 0.918, blue: 0.843) // mint
    public static let spotifyPaused: Color = .secondary
    public static let volumeColor: Color   = Color(red: 0.682, green: 0.776, blue: 0.910) // powder blue
    public static let calendarColor: Color = Color(red: 1.000, green: 0.702, blue: 0.757) // rose
    public static let keyboardColor: Color = Color(red: 0.867, green: 0.714, blue: 0.949) // lavender

    public static let batteryGreen: Color  = Color(red: 0.710, green: 0.918, blue: 0.843)
    public static let batteryYellow: Color = Color(red: 1.000, green: 0.961, blue: 0.729)
    public static let batteryOrange: Color = Color(red: 1.000, green: 0.820, blue: 0.659)
    public static let batteryRed: Color    = Color(red: 1.000, green: 0.702, blue: 0.757)

    // MARK: - Layout
    public static let barHeight: CGFloat = 30
    public static let barMargin: CGFloat = 8
    public static let barContainerHeight: CGFloat = 50
    public static let itemCorner: CGFloat = barHeight / 2
    public static let itemPadBg: CGFloat = 3
    public static let iconPadLeft: CGFloat = 10
    public static let iconPadRight: CGFloat = 4
    public static let labelPadLeft: CGFloat = 4
    public static let labelPadRight: CGFloat = 10
    public static let iconLabelSpacing: CGFloat = iconPadRight + labelPadLeft
    public static let itemGap: CGFloat = 4
    public static let iconSize: CGFloat = 14
    public static let appIconSize: CGFloat = 16
    public static let nowPlayingIconSize: CGFloat = 12
    public static let labelSize: CGFloat = 12
    public static let notchWidth: CGFloat = 160
    public static let menuBarAnimDuration: Double = 0.25
    /// Extra window height below the bar for shadow rendering; content stays pinned to top.
    public static let shadowOverflow: CGFloat = 14

    // MARK: - Config helpers

    public static func color(hex: String?) -> Color? {
        guard let hex, hex.hasPrefix("#"), hex.count == 7 else { return nil }
        let h = String(hex.dropFirst())
        guard let value = UInt64(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >>  8) & 0xFF) / 255
        let b = Double( value        & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}
