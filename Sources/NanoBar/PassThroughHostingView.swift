import AppKit
import SwiftUI

/// Shared store of interactive rects (in window coordinates).
/// Written from SwiftUI preference callbacks, read from hitTest.
@MainActor
final class InteractiveRegionStore {
    static let shared = InteractiveRegionStore()
    private init() {}
    var rects: [CGRect] = []
}

/// NSHostingView subclass that passes mouse events through to windows below
/// for any point not covered by a reported interactive region.
final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: nil)
        let hit = InteractiveRegionStore.shared.rects.contains { $0.contains(localPoint) }
        return hit ? super.hitTest(point) : nil
    }
}
