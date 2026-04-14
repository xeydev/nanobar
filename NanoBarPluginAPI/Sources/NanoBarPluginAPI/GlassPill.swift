import SwiftUI

// MARK: - PillStyle

/// Global pill appearance, injected via @Environment(\.pillStyle).
/// Plugins read this automatically — the host sets it from config.
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

    public init(
        shadow:       Bool       = true,
        border:       Bool       = true,
        borderWidth:  CGFloat    = 0.75,
        borderColor:  Color?     = nil,
        specular:     Bool       = true,
        cornerRadius: CGFloat    = 15,
        material:     PillMaterial = .regularMaterial
    ) {
        self.shadow       = shadow
        self.border       = border
        self.borderWidth  = borderWidth
        self.borderColor  = borderColor
        self.specular     = specular
        self.cornerRadius = cornerRadius
        self.material     = material
    }

    public static let `default` = PillStyle()
}

// MARK: - Environment key

private struct PillStyleKey: EnvironmentKey {
    static let defaultValue = PillStyle.default
}

public extension EnvironmentValues {
    var pillStyle: PillStyle {
        get { self[PillStyleKey.self] }
        set { self[PillStyleKey.self] = newValue }
    }
}

// MARK: - glassPill modifier

public extension View {
    func glassPill(focused: Bool = false, hovered: Bool = false) -> some View {
        modifier(GlassPillModifier(focused: focused, hovered: hovered))
    }
}

public struct GlassPillModifier: ViewModifier {
    public let focused: Bool
    public let hovered: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.pillStyle)   private var pillStyle

    // Mirror Theme.swift layout constants
    private let iconPadLeft:   CGFloat = 10
    private let labelPadRight: CGFloat = 10
    private let barHeight:     CGFloat = 30

    public init(focused: Bool = false, hovered: Bool = false) {
        self.focused = focused
        self.hovered = hovered
    }

    public func body(content: Content) -> some View {
        let radius = pillStyle.cornerRadius
        content
            .padding(.leading,  iconPadLeft)
            .padding(.trailing, labelPadRight)
            .frame(height: barHeight)
            .background(glass(radius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: pillStyle.shadow ? .black.opacity(0.25) : .clear,
                radius: 6, x: 0, y: 3
            )
            .shadow(
                color: pillStyle.shadow ? .black.opacity(0.12) : .clear,
                radius: 2, x: 0, y: 1
            )
    }

    private var whiteOverlayOpacity: Double {
        if focused { return hovered ? 0.25 : 0.18 }
        return colorScheme == .dark ? (hovered ? 0.12 : 0.07) : (hovered ? 0.42 : 0.35)
    }

    @ViewBuilder
    private func glass(radius: CGFloat) -> some View {
        let isDark = colorScheme == .dark
        ZStack {
            switch pillStyle.material {
            case .regularMaterial:
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.regularMaterial)
            case .thinMaterial:
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.thinMaterial)
            case .ultraThinMaterial:
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial)
            case .solid:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.black.opacity(isDark ? 0.6 : 0.08))
            case .none:
                EmptyView()
            }
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(whiteOverlayOpacity))
            if pillStyle.specular {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.white.opacity(focused ? 0.28 : (isDark ? 0.16 : 0.25)), .clear],
                        startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.5)
                    ))
            }
            if pillStyle.border {
                let borderColor = pillStyle.borderColor ?? Color.white.opacity(isDark ? 0.28 : 0.50)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: pillStyle.borderWidth)
            }
        }
    }
}
