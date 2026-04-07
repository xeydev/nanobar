import Foundation

public struct NowPlayingInfo: Sendable {
    public let title: String?
    public let artist: String?
    public let isPlaying: Bool

    public init(title: String?, artist: String?, isPlaying: Bool) {
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
    }
}

/// Push-based now-playing monitor via MediaRemote private framework.
/// Replaces the 2-second polling spotify_watcher.sh entirely.
public final class MediaRemoteMonitor: @unchecked Sendable {
    public static let shared = MediaRemoteMonitor()
    public var onChange: (@MainActor (NowPlayingInfo) -> Void)?

    // MediaRemote function pointers loaded at runtime
    private typealias MRRegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias MRGetNowPlayingFn = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void

    private var mrHandle: UnsafeMutableRawPointer?
    private var mrRegister: MRRegisterFn?
    private var mrGetNowPlaying: MRGetNowPlayingFn?

    private init() {}

    public func start() {
        guard loadFramework() else { return }
        registerForNotifications()
        fetchNowPlaying() // initial value
    }

    private func loadFramework() -> Bool {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else { return false }
        mrHandle = handle

        mrRegister = unsafeBitCast(
            dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications"),
            to: MRRegisterFn?.self
        )
        mrGetNowPlaying = unsafeBitCast(
            dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
            to: MRGetNowPlayingFn?.self
        )
        return mrRegister != nil && mrGetNowPlaying != nil
    }

    private func registerForNotifications() {
        mrRegister?(.main)

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let monitor = Unmanaged<MediaRemoteMonitor>.fromOpaque(observer).takeUnretainedValue()
            monitor.fetchNowPlaying()
        }

        CFNotificationCenterAddObserver(
            center, selfPtr, callback,
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification" as CFString,
            nil, .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center, selfPtr, callback,
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification" as CFString,
            nil, .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center, selfPtr, callback,
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification" as CFString,
            nil, .deliverImmediately
        )
    }

    func fetchNowPlaying() {
        mrGetNowPlaying?(.main) { [weak self] dict in
            guard let self else { return }
            let title   = dict?["kMRMediaRemoteNowPlayingInfoTitle"] as? String
            let artist  = dict?["kMRMediaRemoteNowPlayingInfoArtist"] as? String
            let rate    = dict?["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let info = NowPlayingInfo(title: title, artist: artist, isPlaying: rate > 0)
            let cb = self.onChange
            DispatchQueue.main.async { cb?(info) }
        }
    }
}
