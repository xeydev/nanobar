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

    func body(content: Content) -> some View {
        content
            .padding(.leading,  Theme.iconPadLeft)
            .padding(.trailing, Theme.labelPadRight)
            .frame(height: Theme.barHeight)
            .background(glass)
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }

    private var whiteOverlayOpacity: Double {
        if focused { return hovered ? 0.25 : 0.18 }
        return colorScheme == .dark ? (hovered ? 0.12 : 0.07) : (hovered ? 0.42 : 0.35)
    }

    private var glass: some View {
        let isDark = colorScheme == .dark
        return ZStack {
            Capsule(style: .continuous)
                .fill(.regularMaterial)
            Capsule(style: .continuous)
                .fill(Color.white.opacity(whiteOverlayOpacity))
            Capsule(style: .continuous)
                .fill(LinearGradient(
                    colors: [.white.opacity(focused ? 0.28 : (isDark ? 0.16 : 0.25)), .clear],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.5)
                ))
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(isDark ? 0.28 : 0.50), lineWidth: 0.75)
        }
    }
}
