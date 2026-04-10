import AeroSpaceClient
import SwiftUI
import Monitors

// Reports whether NowPlayingView fits on the right side of the built-in bar.
private struct NowPlayingFitsRightKey: PreferenceKey {
    static let defaultValue = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = nextValue() }
}

public struct BarRootView: View {
    @EnvironmentObject private var state: BarState
    @EnvironmentObject private var config: ConfigLoader
    let isBuiltIn: Bool
    let monitorID: Int
    @State private var nowPlayingFitsRight = true

    public init(isBuiltIn: Bool, monitorID: Int) {
        self.isBuiltIn = isBuiltIn
        self.monitorID = monitorID
    }

    public var body: some View {
        VStack(spacing: 0) {
            Group {
                if isBuiltIn { builtIn } else { external }
            }
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.monitorID, monitorID)
            .environment(\.pillStyle, PillStyle(config.config.pill))
            .environment(\.barStyle, BarStyle(config.config.bar))
            Spacer(minLength: 0)
        }
    }

    // MARK: - Widget dispatch

    @ViewBuilder
    private func widgetView(for id: String) -> some View {
        if let view = WidgetRegistry.shared.view(for: id) {
            view
        }
        // Unknown IDs: error already reported by ConfigLoader at load time; silently skip here.
    }

    @ViewBuilder
    private func zoneWidgets(_ ids: [String]) -> some View {
        ForEach(ids, id: \.self) { id in
            widgetView(for: id)
        }
    }

    // MARK: - Built-in layout (notch avoidance)
    //
    // NowPlaying prefers the right side (just left of the status widgets). If the right
    // half isn't wide enough to fit both NowPlaying and the status widgets without
    // spilling under the notch, ViewThatFits picks the fallback (status widgets only)
    // and reports that via NowPlayingFitsRightKey. The left half then shows NowPlaying
    // right-aligned, safely to the left of the notch.

    private var builtIn: some View {
        HStack(spacing: 0) {
            // Left half: left-zone widgets, and center-zone as fallback if they don't fit right
            HStack(spacing: Theme.itemGap) {
                zoneWidgets(config.config.widgets.left)
                Spacer(minLength: 0)
                if !nowPlayingFitsRight {
                    zoneWidgets(config.config.widgets.center)
                }
            }
            .padding(Theme.barMargin)

            Spacer().frame(width: Theme.notchWidth)

            // Right half: try to fit center-zone here first
            HStack(spacing: Theme.itemGap) {
                Spacer(minLength: 0)
                ViewThatFits(in: .horizontal) {
                    // Preferred: center + right widgets
                    HStack(spacing: Theme.itemGap) {
                        zoneWidgets(config.config.widgets.center)
                        zoneWidgets(config.config.widgets.right)
                    }
                    .preference(key: NowPlayingFitsRightKey.self, value: true)

                    // Fallback: right widgets only; center moves to left half
                    HStack(spacing: Theme.itemGap) {
                        zoneWidgets(config.config.widgets.right)
                    }
                    .preference(key: NowPlayingFitsRightKey.self, value: false)
                }
            }
            .padding(Theme.barMargin)
            .onPreferenceChange(NowPlayingFitsRightKey.self) { nowPlayingFitsRight = $0 }
        }
    }

    // MARK: - External layout (center widgets centered)

    private var external: some View {
        ZStack {
            zoneWidgets(config.config.widgets.center)
            HStack(spacing: Theme.itemGap) {
                zoneWidgets(config.config.widgets.left)
                Spacer()
            }
            HStack(spacing: Theme.itemGap) {
                Spacer()
                zoneWidgets(config.config.widgets.right)
            }
        }
        .padding(Theme.barMargin)
    }
}
