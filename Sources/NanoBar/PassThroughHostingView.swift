import AppKit
import SwiftUI

/// Per-panel store of interactive rects (in window coordinates).
/// Written from SwiftUI preference callbacks on that panel, read from hitTest on that panel.
/// Each BarPanel owns one instance — no shared singleton — so multi-monitor rect sets never clobber each other.
@MainActor
final class InteractiveRegionStore {
    var rects: [CGRect] = []
}

/// NSHostingView subclass that passes mouse events through to windows below
/// for any point not covered by a reported interactive region.
final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    let regionStore: InteractiveRegionStore

    @MainActor
    init(rootView: Content, regionStore: InteractiveRegionStore) {
        self.regionStore = regionStore
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: Content) { fatalError("use init(rootView:regionStore:)") }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("use init(rootView:regionStore:)") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: nil)
        // AppKit guarantees hitTest fires on the main thread; regionStore is @MainActor-isolated.
        let hit = regionStore.rects.contains { $0.contains(localPoint) }
        return hit ? super.hitTest(point) : nil
    }
}
