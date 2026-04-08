import AppKit
import Foundation
import AeroSpaceClient

public final class AeroSpaceMonitor: @unchecked Sendable {
    public static let shared = AeroSpaceMonitor()

    private let broadcaster = MonitorBroadcaster<[WorkspaceState]>()
    private var cachedStates: [WorkspaceState] = []
    private var lastWorkspaceChangeTime: Date = .distantPast

    public func register(_ observer: @escaping @MainActor ([WorkspaceState]) -> Void) {
        broadcaster.register(observer)
    }

    private let notifySocketPath = "/tmp/nanobar-notify.sock"
    private var notifySource: DispatchSourceRead?
    private var serverFD: Int32 = -1

    private init() {}

    public func start() {
        Task { await fetchAndNotify() }
        startNotifySocket()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let name = app.localizedName else { return }
            self?.removeApp(named: name)
        }
    }

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
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bindOK == 0, listen(fd, 5) == 0 else { close(fd); return }
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .userInteractive))
        source.setEventHandler { [weak self] in
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else { return }
            var buf = [UInt8](repeating: 0, count: 64)
            let n = read(clientFD, &buf, buf.count - 1)
            close(clientFD)
            let msg = n > 0
                ? String(bytes: buf.prefix(n), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                : ""
            Task { await self?.handleMessage(msg) }
        }
        source.resume()
        notifySource = source
    }

    // MARK: - Message routing

    /// Socket message protocol:
    ///   W <prev> <next>  — workspace focus changed (env vars from exec-on-workspace-change)
    ///   F                — window-level focus changed (from on-focus-changed)
    ///   M                — focused monitor changed (from on-focused-monitor-changed)
    ///   (anything else)  — full refresh
    private func handleMessage(_ msg: String) async {
        let parts = msg.split(separator: " ", maxSplits: 2).map(String.init)
        switch parts.first {
        case "W":
            guard parts.count == 3 else { await fetchAndNotify(); return }
            lastWorkspaceChangeTime = Date()
            applyFocusChange(prev: parts[1], next: parts[2])
            await fetchWindowsOnly()
        case "F":
            // on-focus-changed co-fires with exec-on-workspace-change on every workspace switch;
            // skip if a W was just handled to avoid a redundant list-windows call.
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
        updateAndBroadcast(updated)
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
        updateAndBroadcast(updated)
    }

    // MARK: - Single-subprocess partial fetches

    private func fetchWindowsOnly() async {
        guard let winOut = try? await AeroSpaceClient.shared.run(args: [
            "list-windows", "--all", "--format", "%{window-id} %{workspace} %{app-name}"
        ]) else { return }

        let wsWindows = parseWindowList(winOut)
        let knownIDs = Set(cachedStates.map { $0.id })
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
                id: wsID,
                isFocused: false,
                windows: Array(wsWindows[wsID]!.prefix(5)),
                monitorID: fallbackMonitorID
            ))
        }
        updated.sort { $0.id < $1.id }
        updateAndBroadcast(updated)
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
        updateAndBroadcast(updated)
    }

    // MARK: - Full fetch (startup + fallback)

    private func fetchAndNotify() async {
        updateAndBroadcast(await fetchWorkspaceStates())
    }

    private func fetchWorkspaceStates() async -> [WorkspaceState] {
        do {
            async let wsTask = AeroSpaceClient.shared.run(args: [
                "list-workspaces", "--all", "--format", "%{workspace} %{monitor-id} %{workspace-is-focused}"
            ])
            async let winTask = AeroSpaceClient.shared.run(args: [
                "list-windows", "--all", "--format", "%{window-id} %{workspace} %{app-name}"
            ])
            let (wsOut, winOut) = try await (wsTask, winTask)
            let (wsMonitor, wsFocused) = parseWorkspaceList(wsOut)
            let wsWindows = parseWindowList(winOut)
            return wsMonitor.keys.sorted().compactMap { wsID -> WorkspaceState? in
                let windows = wsWindows[wsID] ?? []
                let focused = wsFocused[wsID] ?? false
                guard !windows.isEmpty || focused else { return nil }
                return WorkspaceState(
                    id: wsID,
                    isFocused: focused,
                    windows: Array(windows.prefix(5)),
                    monitorID: wsMonitor[wsID]!
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Parsing helpers

    private func parseWindowList(_ output: String) -> [String: [WindowInfo]] {
        var wsWindows: [String: [WindowInfo]] = [:]
        var seen: Set<String> = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2)
            guard parts.count == 3 else { continue }
            let wsID = String(parts[1])
            let appName = String(parts[2])
            let key = "\(wsID):\(appName)"
            guard seen.insert(key).inserted else { continue }
            wsWindows[wsID, default: []].append(WindowInfo(windowID: Int(parts[0]) ?? 0, appName: appName))
        }
        return wsWindows
    }

    private func parseWorkspaceList(_ output: String) -> (monitor: [String: Int], focused: [String: Bool]) {
        var wsMonitor: [String: Int] = [:]
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

    private func updateAndBroadcast(_ states: [WorkspaceState]) {
        cachedStates = states
        broadcaster.notify(states)
    }
}
