import AeroSpaceClient
import SwiftUI

public struct BarRootView: View {
    @EnvironmentObject private var state: BarState
    let isBuiltIn: Bool
    let monitorID: Int

    public init(isBuiltIn: Bool, monitorID: Int) {
        self.isBuiltIn = isBuiltIn
        self.monitorID = monitorID
    }

    private var filteredStates: [WorkspaceState] {
        state.workspaceStates.filter { $0.monitorID == monitorID }
    }

    public var body: some View {
        if isBuiltIn { builtIn } else { external }
    }

    // MARK: - Built-in layout (notch avoidance)

    private var builtIn: some View {
        HStack(spacing: 0) {
            HStack(spacing: Theme.itemGap) {
                WorkspaceBarView(states: filteredStates)
                if state.nowPlaying.title != nil {
                    NowPlayingView(info: state.nowPlaying)
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.barMargin)

            Spacer().frame(width: Theme.notchWidth)

            HStack(spacing: Theme.itemGap) {
                Spacer(minLength: 0)
                rightWidgetsContainer
            }
            .padding(Theme.barMargin)
        }
    }

    // MARK: - External layout (now-playing centered)

    private var external: some View {
        ZStack {
            if state.nowPlaying.title != nil {
                NowPlayingView(info: state.nowPlaying)
            }
            HStack(spacing: Theme.itemGap) {
                WorkspaceBarView(states: filteredStates)
                Spacer()
            }
            HStack(spacing: Theme.itemGap) {
                Spacer()
                rightWidgetsContainer
            }
        }
        .padding(Theme.barMargin)
    }

    private var rightWidgetsContainer: some View {
        HStack(spacing: Theme.itemGap) {
            rightWidgets
        }
    }

    // MARK: - Right-side widgets

    @ViewBuilder
    private var rightWidgets: some View {
        KeyboardView(layout: state.keyboardLayout)
        VolumeView(volume: state.volume)
        BatteryView(info: state.battery)
        ClockView(text: state.clockText)
    }
}
