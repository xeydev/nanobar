import SwiftUI
@_exported import NanoBarPluginAPI

// glassPill() and GlassPillModifier live in NanoBarPluginAPI so plugins can use them.
// This file keeps Widgets-only helpers.

extension View {
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
