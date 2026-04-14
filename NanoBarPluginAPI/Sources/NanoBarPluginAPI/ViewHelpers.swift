import SwiftUI

// MARK: - stableMinWidth

public extension View {
    /// Prevents the view from ever shrinking narrower than its widest rendered width.
    /// Eliminates layout jumps when variable-length text updates.
    func stableMinWidth() -> some View {
        modifier(StableMinWidthModifier())
    }
}

public struct StableMinWidthModifier: ViewModifier {
    @State private var minWidth: CGFloat = 0

    public init() {}

    public func body(content: Content) -> some View {
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

// MARK: - InteractiveRegion

/// Collects CGRects (in window/global coords) of interactive elements.
public struct InteractiveRegionKey: PreferenceKey {
    public static let defaultValue: [CGRect] = []
    public static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

public extension View {
    /// Reports this view's frame (in window coordinates) as an interactive region.
    func interactiveRegion() -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: InteractiveRegionKey.self,
                    value: [geo.frame(in: .global)]
                )
            }
        )
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
