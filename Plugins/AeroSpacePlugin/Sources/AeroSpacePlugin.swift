import AppKit
import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - AeroSpace client

private struct TimeoutError: Error {}

private final class AeroSpaceClient: @unchecked Sendable {
    static let shared = AeroSpaceClient()
    private init() {}

    private static let binaryPaths = [
        "/opt/homebrew/bin/aerospace",
        "/usr/local/bin/aerospace",
        "/usr/bin/aerospace",
    ]

    private static let binaryURL: URL? = binaryPaths
        .map { URL(fileURLWithPath: $0) }
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }

    func run(args: [String]) async throws -> String {
        guard let url = Self.binaryURL else { throw CocoaError(.fileNoSuchFile) }
        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    let process = Process()
                    process.executableURL = url
                    process.arguments = args
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError  = Pipe()
                    process.terminationHandler = { _ in
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                    }
                    do    { try process.run() }
                    catch { continuation.resume(throwing: error) }
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw TimeoutError()
            }
            let result = try await group.next() ?? ""
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Data types

private struct WorkspaceState: Sendable, Equatable {
    let id: String
    let isFocused: Bool
    let windows: [WindowInfo]
    let monitorID: Int
}

private struct WindowInfo: Sendable, Equatable {
    let windowID: Int
    let appName: String
}

// MARK: - Live state

@MainActor
private final class WorkspacesState: ObservableObject, @unchecked Sendable {
    static let shared = WorkspacesState()

    @Published var states: [WorkspaceState] = []

    private var cachedStates: [WorkspaceState] = []
    private var lastWorkspaceChangeTime: Date = .distantPast
    nonisolated(unsafe) private var appTerminationObserver: NSObjectProtocol?

    private let notifySocketPath = "/tmp/nanobar-notify.sock"
    private var notifySource: DispatchSourceRead?
    private var serverFD: Int32 = -1

    init() {
        Task { await fetchAndNotify() }
        startNotifySocket()
        appTerminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let name = app.localizedName else { return }
            MainActor.assumeIsolated { self?.removeApp(named: name) }
        }
    }

    deinit {
        appTerminationObserver.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        notifySource?.cancel()
        if serverFD >= 0 { close(serverFD) }
        // Don't unlink the socket path here — startNotifySocket() handles cleanup on
        // next bind, and unlinking here would destroy a socket created by a newer instance.
    }

    // MARK: - Notify socket

    private func startNotifySocket() {
        unlink(notifySocketPath)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        serverFD = fd
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        notifySocketPath.withCString { cStr in
            withUnsafeMutablePointer(to: &addr.sun_path) {
                _ = strncpy(UnsafeMutableRawPointer($0).assumingMemoryBound(to: CChar.self), cStr, 104)
            }
        }
        let bindOK = withUnsafePointer(to: addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindOK == 0, listen(fd, 5) == 0 else { close(fd); return }
        // Run on main queue so the handler is @MainActor-compatible.
        // accept()+read() on a local domain socket are instant — safe on main.
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler { [weak self] in
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else { return }
            var buf = [UInt8](repeating: 0, count: 64)
            let n = read(clientFD, &buf, buf.count - 1)
            close(clientFD)
            let msg = n > 0
                ? String(bytes: buf.prefix(n), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                : ""
            Task { @MainActor in await self?.handleMessage(msg) }
        }
        source.resume()
        notifySource = source
    }

    // MARK: - Message routing
    //
    //   W <prev> <next>  — workspace focus changed
    //   F                — window-level focus changed
    //   M                — focused monitor changed
    //   (anything else)  — full refresh

    private func handleMessage(_ msg: String) async {
        let parts = msg.split(separator: " ", maxSplits: 2).map(String.init)
        switch parts.first {
        case "W":
            guard parts.count == 3 else { await fetchAndNotify(); return }
            lastWorkspaceChangeTime = Date()
            applyFocusChange(prev: parts[1], next: parts[2])
            await fetchWindowsOnly()
        case "F":
            guard Date().timeIntervalSince(lastWorkspaceChangeTime) > 0.15 else { return }
            await fetchWindowsOnly()
        case "M":
            await fetchWorkspacesOnly()
        default:
            await fetchAndNotify()
        }
    }

    // MARK: - Zero-subprocess cache mutations

    private func applyFocusChange(prev: String, next: String) {
        var updated = cachedStates.map { ws in
            WorkspaceState(
                id: ws.id,
                isFocused: ws.id == next ? true : (ws.id == prev ? false : ws.isFocused),
                windows: ws.windows,
                monitorID: ws.monitorID
            )
        }
        if !updated.contains(where: { $0.id == next }) {
            let monitorID = cachedStates.first { $0.id == prev }?.monitorID ?? 1
            updated.append(WorkspaceState(id: next, isFocused: true, windows: [], monitorID: monitorID))
            updated.sort { $0.id < $1.id }
        }
        updateAndPublish(updated)
    }

    private func removeApp(named name: String) {
        let updated = cachedStates
            .map { ws in
                WorkspaceState(
                    id: ws.id,
                    isFocused: ws.isFocused,
                    windows: ws.windows.filter { $0.appName != name },
                    monitorID: ws.monitorID
                )
            }
            .filter { !$0.windows.isEmpty || $0.isFocused }
        updateAndPublish(updated)
    }

    // MARK: - Single-subprocess partial fetches

    private func fetchWindowsOnly() async {
        guard let winOut = try? await AeroSpaceClient.shared.run(args: [
            "list-windows", "--all", "--format", "%{window-id} %{workspace} %{app-name}"
        ]) else { return }

        let wsWindows = parseWindowList(winOut)
        let knownIDs  = Set(cachedStates.map { $0.id })
        let fallbackMonitorID = cachedStates.first { $0.isFocused }?.monitorID ?? 1

        var updated = cachedStates
            .map { ws in
                WorkspaceState(
                    id: ws.id,
                    isFocused: ws.isFocused,
                    windows: Array((wsWindows[ws.id] ?? []).prefix(5)),
                    monitorID: ws.monitorID
                )
            }
            .filter { !$0.windows.isEmpty || $0.isFocused }

        for wsID in wsWindows.keys where !knownIDs.contains(wsID) {
            updated.append(WorkspaceState(
                id: wsID, isFocused: false,
                windows: Array(wsWindows[wsID]!.prefix(5)),
                monitorID: fallbackMonitorID
            ))
        }
        updated.sort { $0.id < $1.id }
        updateAndPublish(updated)
    }

    private func fetchWorkspacesOnly() async {
        guard let wsOut = try? await AeroSpaceClient.shared.run(args: [
            "list-workspaces", "--all", "--format", "%{workspace} %{monitor-id} %{workspace-is-focused}"
        ]) else { return }

        let (wsMonitor, wsFocused) = parseWorkspaceList(wsOut)
        let windowsByWS = Dictionary(uniqueKeysWithValues: cachedStates.map { ($0.id, $0.windows) })
        let updated = wsMonitor.keys.sorted().compactMap { wsID -> WorkspaceState? in
            let windows = windowsByWS[wsID] ?? []
            let focused = wsFocused[wsID] ?? false
            guard !windows.isEmpty || focused else { return nil }
            return WorkspaceState(id: wsID, isFocused: focused, windows: windows, monitorID: wsMonitor[wsID]!)
        }
        updateAndPublish(updated)
    }

    // MARK: - Full fetch (startup + fallback)

    private func fetchAndNotify() async {
        updateAndPublish(await fetchAll())
    }

    private func fetchAll() async -> [WorkspaceState] {
        do {
            async let wsTask  = AeroSpaceClient.shared.run(args: [
                "list-workspaces", "--all", "--format", "%{workspace} %{monitor-id} %{workspace-is-focused}"
            ])
            async let winTask = AeroSpaceClient.shared.run(args: [
                "list-windows", "--all", "--format", "%{window-id} %{workspace} %{app-name}"
            ])
            let (wsOut, winOut)        = try await (wsTask, winTask)
            let (wsMonitor, wsFocused) = parseWorkspaceList(wsOut)
            let wsWindows              = parseWindowList(winOut)
            return wsMonitor.keys.sorted().compactMap { wsID -> WorkspaceState? in
                let windows = wsWindows[wsID] ?? []
                let focused = wsFocused[wsID] ?? false
                guard !windows.isEmpty || focused else { return nil }
                return WorkspaceState(
                    id: wsID, isFocused: focused,
                    windows: Array(windows.prefix(5)),
                    monitorID: wsMonitor[wsID]!
                )
            }
        } catch { return [] }
    }

    // MARK: - Parsing helpers

    private func parseWindowList(_ output: String) -> [String: [WindowInfo]] {
        var wsWindows: [String: [WindowInfo]] = [:]
        var seen: Set<String> = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2)
            guard parts.count == 3 else { continue }
            let wsID    = String(parts[1])
            let appName = String(parts[2])
            let key     = "\(wsID):\(appName)"
            guard seen.insert(key).inserted else { continue }
            wsWindows[wsID, default: []].append(WindowInfo(windowID: Int(parts[0]) ?? 0, appName: appName))
        }
        return wsWindows
    }

    private func parseWorkspaceList(_ output: String) -> (monitor: [String: Int], focused: [String: Bool]) {
        var wsMonitor: [String: Int]  = [:]
        var wsFocused: [String: Bool] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2)
            guard parts.count >= 2 else { continue }
            let wsID = String(parts[0])
            wsMonitor[wsID] = Int(parts[1]) ?? 1
            wsFocused[wsID] = parts.count > 2 && parts[2].trimmingCharacters(in: .whitespaces) == "true"
        }
        return (wsMonitor, wsFocused)
    }

    private func updateAndPublish(_ newStates: [WorkspaceState]) {
        guard newStates != cachedStates else { return }
        cachedStates = newStates
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            states = newStates
        }
    }
}

// MARK: - Workspace display mode

private enum WorkspaceMode: String {
    case labelsOnly
    case activeIcons
    case clampAndExpand
}

// MARK: - Root view

private struct WorkspaceBarView: View {
    @ObservedObject private var state = WorkspacesState.shared
    @Environment(\.monitorID) private var monitorID

    let mode: WorkspaceMode
    @State private var hoveredID: String?

    private var filtered: [WorkspaceState] {
        state.states.filter { $0.monitorID == monitorID }
    }

    var body: some View {
        HStack(spacing: Theme.itemGap) {
            ForEach(filtered, id: \.id) { ws in
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
            .nanoPill(focused: state.isFocused, hovered: isHovered)
            .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovered = h } }
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
        .nanoPill(focused: state.isFocused, hovered: isHovered)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovered = h } }
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
        .nanoPill(focused: state.isFocused, hovered: isHovered)
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

// MARK: - App icon (shared by all modes)

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
                    Task {
                        try? await AeroSpaceClient.shared.run(args: ["focus", "--window-id", "\(window.windowID)"])
                    }
                }
        }
    }
}

// MARK: - Factory

private final class AeroSpaceWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "workspaces" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        let mode = WorkspaceMode(rawValue: config["mode"] ?? "") ?? .clampAndExpand
        return NanoBarViewBox(AnyView(WorkspaceBarView(mode: mode)))
    }
}

// MARK: - Entry point

@objc(AeroSpacePlugin)
public final class AeroSpacePlugin: NSObject, NanoBarPluginEntry {
    public var pluginID: String { "workspaces" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(AeroSpaceWidgetFactory(config: config))
    }
}
