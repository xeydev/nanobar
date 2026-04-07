import Foundation
import AeroSpaceClient

/// Listens on /tmp/nanobar-notify.sock for workspace-change events from AeroSpace,
/// then queries AeroSpace for full state via its IPC socket.
public final class AeroSpaceMonitor: @unchecked Sendable {
    public static let shared = AeroSpaceMonitor()
    public var onChange: (@MainActor ([WorkspaceState]) -> Void)?

    private let notifySocketPath = "/tmp/nanobar-notify.sock"
    private var notifySource: DispatchSourceRead?
    private var serverFD: Int32 = -1

    private init() {}

    public func start() {
        // Initial fetch
        Task { await self.fetchAndNotify() }
        // Listen for push notifications from exec-on-workspace-change
        startNotifySocket()
    }

    private func startNotifySocket() {
        unlink(notifySocketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        serverFD = fd

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        notifySocketPath.withCString { cStr in
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                _ = strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 104)
            }
        }

        let bindResult = withUnsafePointer(to: addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else { close(fd); return }
        guard listen(fd, 5) == 0 else { close(fd); return }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .userInteractive))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let clientFD = accept(fd, nil, nil)
            if clientFD >= 0 { close(clientFD) }
            Task { await self.fetchAndNotify() }
        }
        source.resume()
        notifySource = source
    }

    private func fetchAndNotify() async {
        let states = await fetchWorkspaceStates()
        let cb = onChange
        await MainActor.run { cb?(states) }
    }

    private func fetchWorkspaceStates() async -> [WorkspaceState] {
        do {
            // 1. All workspaces with focus/monitor info
            let wsOut = try await AeroSpaceClient.shared.run(args: [
                "list-workspaces", "--all",
                "--format", "%{workspace} %{monitor-id} %{workspace-is-focused}"
            ])

            var wsMonitor: [String: Int] = [:]
            var wsFocused: [String: Bool] = [:]

            for line in wsOut.split(separator: "\n") {
                let parts = line.split(separator: " ", maxSplits: 2)
                guard parts.count >= 2 else { continue }
                let wsID = String(parts[0])
                let monID = Int(parts[1]) ?? 1
                let focused = parts.count > 2 && parts[2] == "true"
                wsMonitor[wsID] = monID
                wsFocused[wsID] = focused
            }

            // 2. All windows with workspace/app info
            let winOut = try await AeroSpaceClient.shared.run(args: [
                "list-windows", "--all",
                "--format", "%{window-id} %{workspace} %{app-name}"
            ])

            var wsWindows: [String: [WindowInfo]] = [:]
            var wsDedup: Set<String> = []

            for line in winOut.split(separator: "\n") {
                let parts = line.split(separator: " ", maxSplits: 2)
                guard parts.count == 3 else { continue }
                let winID = Int(parts[0]) ?? 0
                let wsID = String(parts[1])
                let appName = String(parts[2])
                let dedupKey = "\(wsID):\(appName)"
                guard !wsDedup.contains(dedupKey) else { continue }
                wsDedup.insert(dedupKey)
                wsWindows[wsID, default: []].append(WindowInfo(windowID: winID, appName: appName))
            }

            // Build states — filter to non-empty + focused
            return wsMonitor.keys.sorted().compactMap { wsID -> WorkspaceState? in
                let windows = wsWindows[wsID] ?? []
                let focused = wsFocused[wsID] ?? false
                guard !windows.isEmpty || focused else { return nil }
                return WorkspaceState(
                    id: wsID,
                    isFocused: focused,
                    windows: Array(windows.prefix(8)),
                    monitorID: wsMonitor[wsID] ?? 1
                )
            }
        } catch {
            return []
        }
    }
}
