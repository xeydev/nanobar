import SwiftUI

extension View {
    func glassPill(focused: Bool = false, hovered: Bool = false) -> some View {
        modifier(GlassPillModifier(focused: focused, hovered: hovered))
    }

    /// Prevents the view from ever shrinking narrower than its widest rendered width.
    /// Eliminates layout jumps when variable-length text updates.
    func stableMinWidth() -> some View {
        modifier(StableMinWidthModifier())
    }
}

private struct StableMinWidthModifier: ViewModifier {
    @State private var minWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .frame(minWidth: minWidth, alignment: .leading)
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { minWidth = max(minWidth, g.size.width) }
                    .onChange(of: g.size.width) { _, w in
                        if w > minWidth { minWidth = w }
                    }
            })
    }
}

private struct GlassPillModifier: ViewModifier {
    let focused: Bool
    let hovered: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.pillStyle) private var pillStyle

    func body(content: Content) -> some View {
        let radius = pillStyle.cornerRadius
        content
            .padding(.leading,  Theme.iconPadLeft)
            .padding(.trailing, Theme.labelPadRight)
            .frame(height: Theme.barHeight)
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
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isDark ? 0.28 : 0.50), lineWidth: 0.75)
            }
        }
    }
}
