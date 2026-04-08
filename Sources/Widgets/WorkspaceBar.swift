import AeroSpaceClient
import AppKit
import SwiftUI

// ─── Change this line to switch workspace layout mode ───────────────────────
let workspaceMode: WorkspaceMode = .clampAndExpand
// ────────────────────────────────────────────────────────────────────────────

enum WorkspaceMode {
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
    let states: [WorkspaceState]
    /// Shared hover tracking used by Option 3 (ignored by other modes)
    @State private var hoveredID: String?

    public init(states: [WorkspaceState]) { self.states = states }

    public var body: some View {
        HStack(spacing: Theme.itemGap) {
            ForEach(states, id: \.id) { state in
                switch workspaceMode {
                case .labelsOnly:
                    LabelOnlyPill(state: state)
                case .activeIcons:
                    ActiveIconsPill(state: state)
                case .clampAndExpand:
                    ClampExpandPill(state: state, hoveredID: $hoveredID)
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
