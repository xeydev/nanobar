import SwiftUI

// MARK: - GlassVariant

/// Liquid Glass effect variant (macOS 26+).
/// Named GlassVariant to avoid shadowing SwiftUI's Glass type.
public enum GlassVariant: Sendable {
    case regular
    case clear
    case identity
}

// MARK: - GlassStateConfig

/// Appearance for one interaction state (default / hover / toggled).
public struct GlassStateConfig: Sendable {
    public let effect: GlassVariant

    public init(effect: GlassVariant = .clear) {
        self.effect = effect
    }
}

// MARK: - PillStyle

/// Global pill appearance, injected via @Environment(\.pillStyle).
/// Plugins read this automatically — the host sets it from config.
public struct PillStyle: Sendable {
    public enum Variant:      Sendable { case liquidGlass, solid, none }
    public enum BlurMaterial: Sendable { case regular, thin, ultraThin }

    public let variant:       Variant
    public let height:        CGFloat
    public let cornerRadius:  CGFloat
    public let border:        Bool
    public let borderWidth:   CGFloat
    public let borderColor:   Color?          // nil = adaptive
    public let glassDefault:  GlassStateConfig
    public let glassHover:    GlassStateConfig
    public let glassToggled:  GlassStateConfig
    public let blurMaterial:  BlurMaterial    // pre-26 fallback for liquidGlass / solid
    public let blurSpecular:  Bool            // white gradient overlay in blur mode
    public let blurShadow:    Bool            // macOS 26 glass manages its own shadow

    public init(
        variant:      Variant,
        height:       CGFloat,
        cornerRadius: CGFloat,
        border:       Bool,
        borderWidth:  CGFloat,
        borderColor:  Color?,
        glassDefault: GlassStateConfig,
        glassHover:   GlassStateConfig,
        glassToggled: GlassStateConfig,
        blurMaterial: BlurMaterial,
        blurSpecular: Bool,
        blurShadow:   Bool
    ) {
        self.variant      = variant
        self.height       = height
        self.cornerRadius = cornerRadius
        self.border       = border
        self.borderWidth  = borderWidth
        self.borderColor  = borderColor
        self.glassDefault = glassDefault
        self.glassHover   = glassHover
        self.glassToggled = glassToggled
        self.blurMaterial = blurMaterial
        self.blurSpecular = blurSpecular
        self.blurShadow   = blurShadow
    }

    /// Pre-launch fallback — overwritten by `PillStyle.bootstrapDefault()` (called from
    /// AppDelegate) with `PillStyle(NanoConfig.PillConfig())`, the single source of truth.
    /// These explicit values are only reached in SwiftUI previews or isolated tests that
    /// skip host setup. Do not treat them as authoritative defaults.
    // nonisolated(unsafe): written once before any view renders, read-only after that.
    nonisolated(unsafe) public static var `default` = PillStyle(
        variant:      .liquidGlass,
        height:       30,
        cornerRadius: 15,
        border:       true,
        borderWidth:  0.75,
        borderColor:  nil,
        glassDefault: GlassStateConfig(effect: .clear),
        glassHover:   GlassStateConfig(effect: .regular),
        glassToggled: GlassStateConfig(effect: .regular),
        blurMaterial: .regular,
        blurSpecular: true,
        blurShadow:   true
    )
}

// MARK: - Environment keys

private struct PillStyleKey: EnvironmentKey {
    // Computed so it reflects PillStyle.default after the host overrides it at launch.
    static var defaultValue: PillStyle { PillStyle.default }
}

private struct PillHighlightedKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var pillStyle: PillStyle {
        get { self[PillStyleKey.self] }
        set { self[PillStyleKey.self] = newValue }
    }

    /// True when the pill is in hover or toggled state.
    var pillHighlighted: Bool {
        get { self[PillHighlightedKey.self] }
        set { self[PillHighlightedKey.self] = newValue }
    }
}

// MARK: - nanoPill modifier

public extension View {
    func nanoPill(focused: Bool = false, hovered: Bool = false) -> some View {
        modifier(NanoPillModifier(focused: focused, hovered: hovered))
    }
}

public struct NanoPillModifier: ViewModifier {
    public let focused: Bool
    public let hovered: Bool
    @Environment(\.pillStyle) private var pillStyle

    private let iconPadLeft:   CGFloat = 10
    private let labelPadRight: CGFloat = 10

    public init(focused: Bool = false, hovered: Bool = false) {
        self.focused = focused
        self.hovered  = hovered
    }

    public func body(content: Content) -> some View {
        let activeState: GlassStateConfig = hovered ? pillStyle.glassHover
                                          : focused  ? pillStyle.glassToggled
                                          :            pillStyle.glassDefault
        let shape = RoundedRectangle(cornerRadius: pillStyle.cornerRadius, style: .continuous)
        backgrounded(
            content
                // Default foreground: .primary adapts to the glass background automatically.
                // Plugins override per-element with .foregroundStyle(customColor) when needed.
                .foregroundStyle(.primary)
                .environment(\.pillHighlighted, hovered || focused)
                .padding(.leading,  iconPadLeft)
                .padding(.trailing, labelPadRight)
                .frame(height: pillStyle.height),
            shape: shape,
            activeState: activeState
        )
        .interactiveRegion()
    }

    @ViewBuilder
    private func backgrounded<V: View>(_ content: V, shape: RoundedRectangle, activeState: GlassStateConfig) -> some View {
        if #available(macOS 26, *) {
            backgroundedLiquidGlass(content, shape: shape, activeState: activeState)
        } else {
            backgroundedBlur(content, shape: shape)
        }
    }

    @available(macOS 26, *)
    @ViewBuilder
    private func backgroundedLiquidGlass<V: View>(_ content: V, shape: RoundedRectangle, activeState: GlassStateConfig) -> some View {
        switch pillStyle.variant {
        case .liquidGlass:
            let tintOpacity: Double = hovered ? 0.3 : focused ? 0.5 : 0.0
            let glass: Glass = tintOpacity > 0
                ? makeGlass(from: activeState).tint(.white.opacity(tintOpacity))
                : makeGlass(from: activeState)
            content
                .glassEffect(glass, in: shape)
                .overlay { borderOverlay(shape: shape) }
        case .solid:
            backgroundedBlur(content, shape: shape)
        case .none:
            content.clipShape(shape)
        }
    }

    @available(macOS 26, *)
    private func makeGlass(from state: GlassStateConfig) -> Glass {
        switch state.effect {
        case .regular:  return .regular
        case .clear:    return .clear
        case .identity: return .identity
        }
    }

    @ViewBuilder
    private func backgroundedBlur<V: View>(_ content: V, shape: RoundedRectangle) -> some View {
        if case .none = pillStyle.variant {
            content.clipShape(shape)
        } else {
            let material: Material = {
                switch pillStyle.blurMaterial {
                case .thin:      return .thinMaterial
                case .ultraThin: return .ultraThinMaterial
                case .regular:   return .regularMaterial
                }
            }()
            content
                .background {
                    ZStack {
                        shape.fill(material)
                        if pillStyle.blurSpecular {
                            shape.fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                }
                .overlay { borderOverlay(shape: shape) }
                .shadow(
                    color: pillStyle.blurShadow ? .black.opacity(0.35) : .clear,
                    radius: 6, x: 0, y: 3
                )
        }
    }

    @ViewBuilder
    private func borderOverlay(shape: RoundedRectangle) -> some View {
        if pillStyle.border {
            shape.strokeBorder(
                pillStyle.borderColor ?? Color.white.opacity(0.28),
                lineWidth: pillStyle.borderWidth
            )
        }
    }
}
