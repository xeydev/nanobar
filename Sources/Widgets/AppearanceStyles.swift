import SwiftUI
import Monitors
// NanoBarPluginAPI re-exported via NanoPill.swift

// MARK: - PillStyle (NanoConfig initialiser + default bootstrap)

// PillStyle itself lives in NanoBarPluginAPI so plugins can use it.
// This extension adds the NanoConfig-backed initialiser and the bootstrap
// that makes NanoConfig.PillConfig() the single source of truth for the default.
extension PillStyle {
    /// Call once at app startup (before any views render) to make PillStyle.default
    /// derive from NanoConfig.PillConfig() — the single source of truth.
    /// See AppDelegate.applicationDidFinishLaunching.
    public static func bootstrapDefault() {
        PillStyle.default = PillStyle(NanoConfig.PillConfig())
    }

    init(_ config: NanoConfig.PillConfig) {
        let variant: Variant = {
            switch config.style {
            case "solid": return .solid
            case "none":  return .none
            default:      return .liquidGlass
            }
        }()

        let mapEffect: (String) -> GlassVariant = {
            switch $0 {
            case "regular":  return .regular
            case "identity": return .identity
            default:         return .clear
            }
        }

        let mapBlurMaterial: (String) -> BlurMaterial = {
            switch $0 {
            case "thin":      return .thin
            case "ultraThin": return .ultraThin
            default:          return .regular
            }
        }

        let g = config.liquidGlass

        self.init(
            variant:      variant,
            height:       CGFloat(config.height),
            cornerRadius: CGFloat(config.cornerRadius),
            border:       config.border.isEnabled,
            borderWidth:  CGFloat(config.border.width),
            borderColor:  config.border.customColor.flatMap { Theme.color(hex: $0) },
            glassDefault: GlassStateConfig(effect: mapEffect(g.defaultEffect)),
            glassHover:   GlassStateConfig(effect: mapEffect(g.hoverEffect)),
            glassToggled: GlassStateConfig(effect: mapEffect(g.toggledEffect)),
            blurMaterial: mapBlurMaterial(g.blur.material),
            blurSpecular: g.blur.specular,
            blurShadow:   g.blur.shadow
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
    public let minHeight:    CGFloat
    public let cornerRadius: CGFloat
    public let shadow:       Bool
    public let margin:       EdgeInsets   // screen edge → bar background
    public let padding:      EdgeInsets   // bar background → pill widgets
    public let border:       Bool
    public let borderWidth:  CGFloat
    public let borderColor:  Color

    public init(_ config: NanoConfig.BarConfig) {
        minHeight    = CGFloat(config.minHeight)
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

// monitorID environment key lives in NanoBarPluginAPI (re-exported via NanoPill.swift).
