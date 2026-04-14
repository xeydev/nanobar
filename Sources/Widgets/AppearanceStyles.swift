import SwiftUI
import Monitors
// NanoBarPluginAPI re-exported via GlassPill.swift

// MARK: - PillStyle (NanoConfig initialiser)

// PillStyle itself lives in NanoBarPluginAPI so plugins can use it.
// This extension adds the NanoConfig-backed initialiser used by the host only.
extension PillStyle {
    init(_ config: NanoConfig.PillConfig) {
        self.init(
            shadow:       config.shadow,
            border:       config.border.isEnabled,
            borderWidth:  CGFloat(config.border.width),
            borderColor:  config.border.customColor.flatMap { Theme.color(hex: $0) },
            specular:     config.specular,
            cornerRadius: CGFloat(config.cornerRadius),
            material: {
                switch config.material {
                case "thin":      return .thinMaterial
                case "ultraThin": return .ultraThinMaterial
                case "solid":     return .solid
                case "none":      return .none
                default:          return .regularMaterial
                }
            }()
        )
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
        borderColor  = Theme.color(hex: config.border.customColor ?? BorderConfig.defaultColor) ?? Color.white.opacity(0.35)
        margin  = config.margin.asEdgeInsets
        padding = config.padding.asEdgeInsets
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

private extension SideInsets {
    var asEdgeInsets: EdgeInsets {
        EdgeInsets(top: CGFloat(top), leading: CGFloat(left),
                   bottom: CGFloat(bottom), trailing: CGFloat(right))
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

// monitorID environment key lives in NanoBarPluginAPI (re-exported via GlassPill.swift).
