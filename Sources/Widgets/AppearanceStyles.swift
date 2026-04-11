import SwiftUI
import Monitors

// MARK: - PillStyle

/// Global pill appearance derived from the [pill] config section.
/// Injected via @Environment(\.pillStyle) so all widgets pick it up automatically.
public struct PillStyle: Sendable {
    public let shadow:       Bool
    public let border:       Bool
    public let borderWidth:  CGFloat
    public let borderColor:  Color?   // nil = adaptive (dark/light)
    public let specular:     Bool
    public let cornerRadius: CGFloat
    public let material:     PillMaterial

    public enum PillMaterial: Sendable {
        case regularMaterial
        case thinMaterial
        case ultraThinMaterial
        case solid
        case none
    }

    public init(_ config: NanoConfig.PillConfig) {
        shadow       = config.shadow
        border       = config.border.isEnabled
        borderWidth  = CGFloat(config.border.width)
        borderColor  = config.border.customColor.flatMap { Theme.color(hex: $0) }
        specular     = config.specular
        cornerRadius = CGFloat(config.cornerRadius)
        material = switch config.material {
        case "thin":      .thinMaterial
        case "ultraThin": .ultraThinMaterial
        case "solid":     .solid
        case "none":      .none
        default:          .regularMaterial   // "glass" or anything unrecognized
        }
    }

    public static let `default` = PillStyle(NanoConfig.PillConfig())
}

private struct PillStyleKey: EnvironmentKey {
    static let defaultValue = PillStyle.default
}

public extension EnvironmentValues {
    var pillStyle: PillStyle {
        get { self[PillStyleKey.self] }
        set { self[PillStyleKey.self] = newValue }
    }
}

// MARK: - BarStyle

/// Bar-level appearance derived from the [bar] config section.
public struct BarStyle: Sendable {
    public enum Background: Sendable {
        case none
        case blur
        case color(Double, Double, Double, Double)  // r, g, b, a  (0–1)
    }
    public let background:   Background
    public let height:       CGFloat
    public let cornerRadius: CGFloat
    public let shadow:       Bool
    public let margin:       EdgeInsets   // screen edge → bar background
    public let padding:      EdgeInsets   // bar background → pill widgets
    public let border:       Bool
    public let borderWidth:  CGFloat
    public let borderColor:  Color

    public init(_ config: NanoConfig.BarConfig) {
        height       = CGFloat(config.height)
        cornerRadius = CGFloat(config.cornerRadius)
        shadow       = config.shadow
        border       = config.border.isEnabled
        borderWidth  = CGFloat(config.border.width)
        borderColor  = Theme.color(hex: config.border.customColor ?? "#FFFFFF59") ?? Color.white.opacity(0.35)
        margin  = EdgeInsets(top: CGFloat(config.margin.top),   leading: CGFloat(config.margin.left),
                             bottom: CGFloat(config.margin.bottom), trailing: CGFloat(config.margin.right))
        padding = EdgeInsets(top: CGFloat(config.padding.top),  leading: CGFloat(config.padding.left),
                             bottom: CGFloat(config.padding.bottom), trailing: CGFloat(config.padding.right))
        let raw = config.background.trimmingCharacters(in: .whitespaces)
        if raw == "blur" {
            background = .blur
        } else if raw.lowercased().hasPrefix("color:") {
            let hex = String(raw.dropFirst(6))
            background = BarStyle.parseHexColor(hex) ?? .none
        } else {
            background = .none
        }
    }

    public static let `default` = BarStyle(NanoConfig.BarConfig())

    private static func parseHexColor(_ hex: String) -> Background? {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        // Support #RRGGBB (alpha=1) and #RRGGBBAA
        let count = h.count
        guard count == 6 || count == 8,
              let value = UInt64(h, radix: 16) else { return nil }
        if count == 6 {
            let r = Double((value >> 16) & 0xFF) / 255
            let g = Double((value >>  8) & 0xFF) / 255
            let b = Double( value        & 0xFF) / 255
            return .color(r, g, b, 1)
        } else {
            let r = Double((value >> 24) & 0xFF) / 255
            let g = Double((value >> 16) & 0xFF) / 255
            let b = Double((value >>  8) & 0xFF) / 255
            let a = Double( value        & 0xFF) / 255
            return .color(r, g, b, a)
        }
    }
}

private struct BarStyleKey: EnvironmentKey {
    static let defaultValue = BarStyle.default
}

public extension EnvironmentValues {
    var barStyle: BarStyle {
        get { self[BarStyleKey.self] }
        set { self[BarStyleKey.self] = newValue }
    }
}

// MARK: - MonitorID environment key

private struct MonitorIDKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

public extension EnvironmentValues {
    var monitorID: Int {
        get { self[MonitorIDKey.self] }
        set { self[MonitorIDKey.self] = newValue }
    }
}
