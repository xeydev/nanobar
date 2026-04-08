import SwiftUI

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
