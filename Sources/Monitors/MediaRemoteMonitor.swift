import Foundation

public struct NowPlayingInfo: Sendable {
    public let title: String?
    public let artist: String?
    public let isPlaying: Bool
    public init(title: String?, artist: String?, isPlaying: Bool) {
        self.title = title; self.artist = artist; self.isPlaying = isPlaying
    }
}

/// Push-based now-playing monitor via a persistent NowPlayingHelper subprocess.
/// The helper subscribes to MediaRemote notifications and writes a JSON line per change.
public final class MediaRemoteMonitor: @unchecked Sendable {
    public static let shared = MediaRemoteMonitor()

    private let broadcaster = MonitorBroadcaster<NowPlayingInfo>()

    public func register(_ observer: @escaping @MainActor (NowPlayingInfo) -> Void) {
        broadcaster.register(observer)
    }

    private var process: Process?
    private init() {}

    private static let helperURL: URL = {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0])
        return exe.deletingLastPathComponent().appendingPathComponent("NowPlayingHelper")
    }()

    public func start() {
        let proc = Process()
        proc.executableURL = Self.helperURL
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.start() }
        }
        guard (try? proc.run()) != nil else { return }
        process = proc

        let fh = pipe.fileHandleForReading
        fh.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else { return }
            for line in text.components(separatedBy: "\n") {
                self.handle(line: line)
            }
        }
    }

    private func handle(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let title  = json["title"]  as? String
        let artist = json["artist"] as? String
        let rate   = json["rate"]   as? Double ?? 0

        let info = NowPlayingInfo(
            title:  title.flatMap  { $0.isEmpty ? nil : $0 },
            artist: artist.flatMap { $0.isEmpty ? nil : $0 },
            isPlaying: rate > 0
        )
        broadcaster.notify(info)
    }
}
