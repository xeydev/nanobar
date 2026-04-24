import AppKit
import SwiftUI

public enum Theme {
    // MARK: - Colors (adaptive — correct on dark, light, and liquid glass)
    public static let iconColor: Color     = adaptive(
        light: Color(red: 0.50, green: 0.18, blue: 0.72),  // purple
        dark:  Color(red: 0.867, green: 0.714, blue: 0.949) // lavender
    )
    public static let labelColor: Color    = .primary
    public static let grey: Color          = .secondary

    public static let spotifyActive: Color = adaptive(
        light: Color(red: 0.02, green: 0.52, blue: 0.42),   // teal
        dark:  Color(red: 0.710, green: 0.918, blue: 0.843) // mint
    )
    public static let spotifyPaused: Color = .secondary
    public static let volumeColor: Color   = adaptive(
        light: Color(red: 0.18, green: 0.40, blue: 0.72),   // steel blue
        dark:  Color(red: 0.682, green: 0.776, blue: 0.910) // powder blue
    )
    public static let calendarColor: Color = adaptive(
        light: Color(red: 0.78, green: 0.14, blue: 0.28),   // crimson
        dark:  Color(red: 1.000, green: 0.702, blue: 0.757) // rose
    )
    public static let keyboardColor: Color = adaptive(
        light: Color(red: 0.50, green: 0.18, blue: 0.72),   // purple
        dark:  Color(red: 0.867, green: 0.714, blue: 0.949) // lavender
    )

    public static let batteryGreen: Color  = adaptive(
        light: Color(red: 0.08, green: 0.58, blue: 0.08),   // forest green
        dark:  Color(red: 0.710, green: 0.918, blue: 0.843) // mint
    )
    public static let batteryYellow: Color = adaptive(
        light: Color(red: 0.65, green: 0.48, blue: 0.00),   // dark amber
        dark:  Color(red: 1.000, green: 0.961, blue: 0.729) // pale yellow
    )
    public static let batteryOrange: Color = adaptive(
        light: Color(red: 0.78, green: 0.38, blue: 0.00),   // dark orange
        dark:  Color(red: 1.000, green: 0.820, blue: 0.659) // peach
    )
    public static let batteryRed: Color    = adaptive(
        light: Color(red: 0.78, green: 0.08, blue: 0.08),   // dark red
        dark:  Color(red: 1.000, green: 0.702, blue: 0.757) // rose
    )

    public static let tmuxColor:          Color = adaptive(
        light: Color(red: 0.08, green: 0.52, blue: 0.08),   // forest green
        dark:  Color(red: 0.678, green: 0.918, blue: 0.686) // mint-green
    )
    public static let pomodoroWorkColor:  Color = adaptive(
        light: Color(red: 0.80, green: 0.08, blue: 0.08),   // dark red
        dark:  Color(red: 1.000, green: 0.420, blue: 0.420) // soft red
    )
    public static let pomodoroBreakColor: Color = spotifyActive

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
    public static let batteryIconWidth: CGFloat = 26
    /// Extra window height below the bar for shadow rendering; content stays pinned to top.
    public static let shadowOverflow: CGFloat = 14

    // MARK: - Battery thresholds
    public static let batteryWarnThreshold: Int = 75
    public static let batteryMedThreshold:  Int = 50
    public static let batteryLowThreshold:  Int = 25

    // MARK: - Bar shadow
    public static let barShadowOpacity: Double  = 0.3
    public static let barShadowRadius:  CGFloat = 8
    public static let barShadowY:       CGFloat = 4

    // MARK: - Animations
    public static let menuBarAnimDuration: Double    = 0.25
    public static let animEase:            Animation = .easeInOut(duration: 0.3)
    public static let animEaseSlow:        Animation = .easeInOut(duration: 0.4)
    public static let springIconHover:     Animation = .spring(response: 0.2, dampingFraction: 0.7)
    public static let springLabelHover:    Animation = .spring(response: 0.3, dampingFraction: 0.75)

    // MARK: - Config helpers

    /// Returns an adaptive Color that resolves to `dark` in Dark Mode and `light` in Light Mode.
    /// Uses NSColor's dynamic provider — the same mechanism NSApp.appearance drives —
    /// so colors update on theme switch and respect vibrancy behind glass materials.
    public static func adaptive(light: Color, dark: Color) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua: return NSColor(dark)
            default:        return NSColor(light)
            }
        }))
    }

    public static func color(hex: String?) -> Color? {
        guard let hex, hex.hasPrefix("#") else { return nil }
        let h = String(hex.dropFirst())
        guard let value = UInt64(h, radix: 16) else { return nil }
        switch h.count {
        case 6:
            let r = Double((value >> 16) & 0xFF) / 255
            let g = Double((value >>  8) & 0xFF) / 255
            let b = Double( value        & 0xFF) / 255
            return Color(red: r, green: g, blue: b)
        case 8:
            let r = Double((value >> 24) & 0xFF) / 255
            let g = Double((value >> 16) & 0xFF) / 255
            let b = Double((value >>  8) & 0xFF) / 255
            let a = Double( value        & 0xFF) / 255
            return Color(red: r, green: g, blue: b, opacity: a)
        default:
            return nil
        }
    }
}

// MARK: - Color hex encoding

public extension Color {
    /// Encodes the color as an 8-digit hex string `"#RRGGBBAA"` in sRGB.
    /// Returns nil if the color space conversion fails.
    func toHex8() -> String? {
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int((ns.redComponent   * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent  * 255).rounded())
        let a = Int((ns.alphaComponent * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}
