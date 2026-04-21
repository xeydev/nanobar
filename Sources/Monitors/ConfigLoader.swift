import Foundation
import TOMLKit
import UserNotifications

// MARK: - Error type

public enum ConfigError: Error, LocalizedError, Sendable {
    case fileNotReadable(String)
    case parseError(String)
    case bundleNotFound(path: String)
    case invalidPrincipalClass(path: String)
    case unknownWidgetID(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotReadable(let path):
            return "Cannot read config file at \(path)"
        case .parseError(let msg):
            return "Config parse error: \(msg)"
        case .bundleNotFound(let path):
            return "Plugin bundle not found: \(path)"
        case .invalidPrincipalClass(let path):
            return "Plugin has no valid principal class: \(path)"
        case .unknownWidgetID(let id):
            return "Unknown widget ID in config: \"\(id)\""
        }
    }
}

// MARK: - ConfigLoader

@MainActor
public final class ConfigLoader: ObservableObject {
    public static let shared = ConfigLoader()

    @Published public private(set) var config    = NanoConfig.defaults
    @Published public private(set) var lastError: ConfigError?

    /// Set by AppDelegate. Called on the main actor after every successful reload.
    public var onReload: (@MainActor () -> Void)?

    private let configURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/nanobar/config.toml")
    }()

    private var dirWatchSource:  DispatchSourceFileSystemObject?
    private var fileWatchSource: DispatchSourceFileSystemObject?
    private var lastNotifiedError: String?

    private init() {}

    // MARK: - Public interface

    /// Write the default config if the file is missing, then start watching for changes.
    public func loadOrCreate() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configURL.path) {
            let dir = configURL.deletingLastPathComponent()
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try? NanoConfig.defaultTOML.write(to: configURL, atomically: true, encoding: .utf8)
        }
        reload()
        watch()
    }

    /// Parse the config file. On success updates `config` and calls `onReload`.
    /// On failure updates `lastError` and leaves `config` unchanged.
    public func reload() {
        guard let raw = try? String(contentsOf: configURL, encoding: .utf8) else {
            report(.fileNotReadable(configURL.path)); return
        }
        do {
            let decoded = try TOMLDecoder().decode(NanoConfig.self, from: raw)
            config    = decoded
            lastError = nil
            lastNotifiedError = nil
            onReload?()
        } catch {
            report(.parseError(error.localizedDescription))
        }
    }

    /// Surface an error: update `lastError`, log to stderr, post a macOS notification.
    public func report(_ error: ConfigError) {
        lastError = error
        let msg = error.localizedDescription
        fputs("[NanoBar] \(msg)\n", stderr)
        // Deduplicate notifications for the same error message
        guard lastNotifiedError != msg else { return }
        lastNotifiedError = msg
        postNotification(body: msg)
    }

    // MARK: - File watching

    private func watch() {
        // Watch the directory for write events (catches atomic saves: temp-file + rename).
        let dirFd = open(configURL.deletingLastPathComponent().path, O_EVTONLY)
        if dirFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: dirFd, eventMask: .write, queue: .main)
            src.setEventHandler { [weak self] in
                guard let self else { return }
                self.reload()
            }
            src.setCancelHandler { close(dirFd) }
            src.resume()
            dirWatchSource = src
        }

        // Also watch the file directly for write events (catches in-place saves).
        // After an atomic rename the fd becomes stale, but the dir watcher still fires
        // for subsequent atomic saves, so this only needs to cover in-place writes.
        watchFile()
    }

    private func watchFile() {
        let fileFd = open(configURL.path, O_EVTONLY)
        guard fileFd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileFd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self, weak src] in
            guard let self else { return }
            self.reload()
            // File was replaced atomically (rename/delete) — re-attach to the new inode.
            if let data = src?.data, !data.intersection([.rename, .delete]).isEmpty {
                self.fileWatchSource?.cancel()
                self.fileWatchSource = nil
                self.watchFile()
            }
        }
        src.setCancelHandler { close(fileFd) }
        src.resume()
        fileWatchSource = src
    }

    // MARK: - Notifications

    private func postNotification(body: String) {
        // UNUserNotificationCenter requires a bundle ID — guard against raw-binary launches.
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "NanoBar Config Error"
            content.body  = body
            let req = UNNotificationRequest(
                identifier: "nanobar.config.error",
                content: content,
                trigger: nil
            )
            center.add(req, withCompletionHandler: nil)
        }
    }
}
