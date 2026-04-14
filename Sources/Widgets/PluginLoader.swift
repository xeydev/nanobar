import Foundation
import Monitors
import NanoBarPluginAPI

// MARK: - PluginLoader

/// Loads plugin bundles and registers their widgets into WidgetRegistry.
///
/// Standard plugins are auto-discovered from the `Plugins/` directory next to the
/// binary (dev) or `Contents/PlugIns/` inside the app bundle (production).
/// User config `[plugins.<id>]` sections provide settings; no `bundle` key needed
/// for standard plugins. Custom/third-party plugins still require a `bundle` path.
///
/// Bundles are loaded once (NSBundle limitation). On every `loadPlugins` call all
/// previously registered plugins are re-registered with current config settings,
/// so hot-reload picks up setting changes without restarting.
@MainActor
public final class PluginLoader {
    public static let shared = PluginLoader()

    private struct LoadedPlugin {
        let bundlePath: String
        let pluginID: String
        let entry: any NanoBarPluginEntry
    }

    private var loaded: [LoadedPlugin] = []
    private init() {}

    public func loadPlugins(config: NanoConfig, registry: WidgetRegistry) {
        // Auto-discover standard plugins (idempotent — skips already-loaded bundles).
        if let dir = standardPluginsDir {
            discoverBundles(in: dir, config: config)
        }
        // Load any user-specified external bundles (those with an explicit `bundle` key).
        for (id, entry) in config.plugins {
            guard let path = entry.bundle else { continue }
            loadBundle(at: URL(fileURLWithPath: path), pluginID: id)
        }
        // Re-register ALL loaded plugins with current settings (enables hot-reload).
        let bridge = RegistryBridge(inner: registry)
        for plug in loaded {
            let settings = config.plugins[plug.pluginID]?.settings ?? [:]
            plug.entry.registerWidgets(with: bridge, config: settings)
        }
    }

    // MARK: - Private

    private func discoverBundles(in dir: URL, config: NanoConfig) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let alreadyLoaded = Set(loaded.map { $0.bundlePath })
        for url in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.pathExtension == "bundle", !alreadyLoaded.contains(url.path) else { continue }
            loadBundle(at: url, pluginID: nil)
        }
    }

    /// Loads a bundle and appends it to `loaded`. `pluginID` is read from the entry
    /// if nil (requires the protocol's `pluginID` property).
    private func loadBundle(at url: URL, pluginID: String?) {
        let alreadyLoaded = Set(loaded.map { $0.bundlePath })
        guard !alreadyLoaded.contains(url.path) else { return }
        guard let bundle = Bundle(url: url), bundle.load() else {
            ConfigLoader.shared.report(.bundleNotFound(path: url.path))
            return
        }
        guard
            let cls   = bundle.principalClass as? NSObject.Type,
            let entry = cls.init() as? (any NanoBarPluginEntry)
        else {
            ConfigLoader.shared.report(.invalidPrincipalClass(path: url.path))
            return
        }
        let id = pluginID ?? entry.pluginID
        loaded.append(LoadedPlugin(bundlePath: url.path, pluginID: id, entry: entry))
    }

    /// Returns the directory to scan for standard plugin bundles.
    /// Prefers the app bundle's `PlugIns/` directory (production), then
    /// a `Plugins/` sibling of the binary (development / SwiftPM builds).
    private var standardPluginsDir: URL? {
        if let url = Bundle.main.builtInPlugInsURL,
           FileManager.default.fileExists(atPath: url.path) { return url }
        let binary = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0], isDirectory: false)
        let dir    = binary.deletingLastPathComponent().appendingPathComponent("Plugins")
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
    }
}
