import Foundation
import AeroSpaceClient

public final class AeroSpaceMonitor: @unchecked Sendable {
    public static let shared = AeroSpaceMonitor()

    private let broadcaster = MonitorBroadcaster<[WorkspaceState]>()

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
            if clientFD >= 0 { close(clientFD) }
            Task { await self?.fetchAndNotify() }
        }
        source.resume()
        notifySource = source
    }

    private func fetchAndNotify() async {
        broadcaster.notify(await fetchWorkspaceStates())
    }

    private func fetchWorkspaceStates() async -> [WorkspaceState] {
        do {
            async let wsTask = AeroSpaceClient.shared.run(args: [
                "list-workspaces", "--all",
                "--format", "%{workspace} %{monitor-id} %{workspace-is-focused}"
            ])
            async let winTask = AeroSpaceClient.shared.run(args: [
                "list-windows", "--all",
                "--format", "%{window-id} %{workspace} %{app-name}"
            ])
            let (wsOut, winOut) = try await (wsTask, winTask)

            var wsMonitor: [String: Int] = [:]
            var wsFocused: [String: Bool] = [:]
            for line in wsOut.split(separator: "\n") {
                let parts = line.split(separator: " ", maxSplits: 2)
                guard parts.count >= 2 else { continue }
                wsMonitor[String(parts[0])] = Int(parts[1]) ?? 1
                wsFocused[String(parts[0])] = parts.count > 2 && parts[2].trimmingCharacters(in: .whitespaces) == "true"
            }

            var wsWindows: [String: [WindowInfo]] = [:]
            var wsDedup: Set<String> = []
            for line in winOut.split(separator: "\n") {
                let parts = line.split(separator: " ", maxSplits: 2)
                guard parts.count == 3 else { continue }
                let winID = Int(parts[0]) ?? 0
                let wsID = String(parts[1])
                let appName = String(parts[2])
                let key = "\(wsID):\(appName)"
                guard !wsDedup.contains(key) else { continue }
                wsDedup.insert(key)
                wsWindows[wsID, default: []].append(WindowInfo(windowID: winID, appName: appName))
            }

            return wsMonitor.keys.sorted().compactMap { wsID -> WorkspaceState? in
                let windows = wsWindows[wsID] ?? []
                let focused = wsFocused[wsID] ?? false
                guard !windows.isEmpty || focused else { return nil }
                return WorkspaceState(
                    id: wsID,
                    isFocused: focused,
                    windows: Array(windows.prefix(5)),
                    monitorID: wsMonitor[wsID] ?? 1
                )
            }
        } catch {
            return []
        }
    }
}
