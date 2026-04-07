import AeroSpaceClient
import AppKit
import SwiftUI

public struct WorkspaceBarView: View {
    let states: [WorkspaceState]
    public init(states: [WorkspaceState]) { self.states = states }

    public var body: some View {
        HStack(spacing: Theme.itemGap) {
            ForEach(states, id: \.id) { state in
                WorkspaceGroupView(state: state)
            }
        }
    }
}

// MARK: - Single workspace pill

private struct WorkspaceGroupView: View {
    let state: WorkspaceState
    @EnvironmentObject private var barState: BarState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(state.id)
                .font(.system(size: Theme.labelSize, weight: .semibold))
                .foregroundStyle(state.isFocused ? Theme.labelColor : Theme.grey)
            ForEach(state.windows.prefix(5), id: \.windowID) { window in
                AppIconView(window: window)
            }
        }
        .glassPill(focused: state.isFocused, hovered: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            if hovering { barState.hoverBegan() } else { barState.hoverEnded() }
        }
        .onTapGesture {
            Task { try? await AeroSpaceClient.shared.run(args: ["workspace", state.id]) }
        }
    }
}

private struct AppIconView: View {
    let window: WindowInfo
    @EnvironmentObject private var barState: BarState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var icon: NSImage? {
        NSWorkspace.shared.runningApplications.first { $0.localizedName == window.appName }?.icon
    }

    var body: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: Theme.appIconSize, height: Theme.appIconSize)
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering { barState.hoverBegan() } else { barState.hoverEnded() }
                }
                .onTapGesture {
                    Task { try? await AeroSpaceClient.shared.run(args: ["focus", "--window-id", "\(window.windowID)"]) }
                }
        }
    }
}
