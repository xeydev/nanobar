import AeroSpaceClient
import AppKit
import SwiftUI
import Monitors

// MARK: - WorkspaceMode

public enum WorkspaceMode: String {
    /// Option 1 — flat label strip; no app icons shown
    case labelsOnly
    /// Option 2 — only the focused workspace shows app icons; others are label-only
    case activeIcons
    /// Option 3 — all workspaces show icons clamped to fit; hovering expands
    ///             the pill with a spring animation while others contract
    case clampAndExpand
}

// MARK: - Root

public struct WorkspaceBarView: View {
    @EnvironmentObject private var state: BarState
    @Environment(\.monitorID) private var monitorID

    private let mode: WorkspaceMode

    @State private var hoveredID: String?

    public init(config: [String: String]) {
        mode = WorkspaceMode(rawValue: config["mode"] ?? "") ?? .clampAndExpand
    }

    private var filteredStates: [WorkspaceState] {
        state.workspaceStates.filter { $0.monitorID == monitorID }
    }

    public var body: some View {
        HStack(spacing: Theme.itemGap) {
            ForEach(filteredStates, id: \.id) { ws in
                switch mode {
                case .labelsOnly:
                    LabelOnlyPill(state: ws)
                case .activeIcons:
                    ActiveIconsPill(state: ws)
                case .clampAndExpand:
                    ClampExpandPill(state: ws, hoveredID: $hoveredID)
                }
            }
        }
    }
}

// MARK: - Option 1: Labels Only

private struct LabelOnlyPill: View {
    let state: WorkspaceState
    @State private var isHovered = false

    var body: some View {
        Text(state.id)
            .font(.system(size: Theme.labelSize, weight: .semibold))
            .foregroundStyle(state.isFocused ? Theme.labelColor : Theme.grey)
            .glassPill(focused: state.isFocused, hovered: isHovered)
        .interactiveRegion()
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering } }
        .onTapGesture {
            Task { try? await AeroSpaceClient.shared.run(args: ["workspace", state.id]) }
        }
    }
}

// MARK: - Option 2: Active Icons

private struct ActiveIconsPill: View {
    let state: WorkspaceState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(state.id)
                .font(.system(size: Theme.labelSize, weight: .semibold))
                .foregroundStyle(state.isFocused ? Theme.labelColor : Theme.grey)
            if state.isFocused {
                ForEach(state.windows.prefix(5), id: \.windowID) { window in
                    AppIconView(window: window)
                }
            }
        }
        .glassPill(focused: state.isFocused, hovered: isHovered)
        .interactiveRegion()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture {
            Task { try? await AeroSpaceClient.shared.run(args: ["workspace", state.id]) }
        }
    }
}

// MARK: - Option 3: Clamp & Expand

private struct ClampExpandPill: View {
    let state: WorkspaceState
    @Binding var hoveredID: String?

    private var isHovered: Bool { hoveredID == state.id }

    /// How many icons to show. Snaps to whole icons — no partial clipping.
    private var visibleIconCount: Int {
        if isHovered || state.isFocused { return min(state.windows.count, 5) }
        return 0
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(state.id)
                .font(.system(size: Theme.labelSize, weight: .semibold))
                .foregroundStyle(state.isFocused ? Theme.labelColor : Theme.grey)
                .fixedSize()

            if visibleIconCount > 0 {
                HStack(spacing: 4) {
                    ForEach(state.windows.prefix(visibleIconCount), id: \.windowID) { window in
                        AppIconView(window: window)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
            }
        }
        .glassPill(focused: state.isFocused, hovered: isHovered)
        .interactiveRegion()
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                hoveredID = hovering ? state.id : nil
            }
        }
        .onTapGesture {
            Task { try? await AeroSpaceClient.shared.run(args: ["workspace", state.id]) }
        }
    }
}

// MARK: - App Icon (shared by all modes)

private struct AppIconView: View {
    let window: WindowInfo
    @State private var isHovered = false
    @State private var icon: NSImage?

    init(window: WindowInfo) {
        self.window = window
        _icon = State(initialValue:
            NSWorkspace.shared.runningApplications
                .first { $0.localizedName == window.appName }?.icon
        )
    }

    var body: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: Theme.appIconSize, height: Theme.appIconSize)
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
                .interactiveRegion()
                .onHover { isHovered = $0 }
                .onTapGesture {
                    Task { try? await AeroSpaceClient.shared.run(args: ["focus", "--window-id", "\(window.windowID)"]) }
                }
        }
    }
}
