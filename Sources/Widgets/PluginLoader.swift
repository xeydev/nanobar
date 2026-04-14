import Foundation
import Monitors
import NanoBarPluginAPI

// MARK: - PluginLoader

/// Scans plugin entries in config and loads any that have a "bundle" key.
/// Built-in plugin sections (no "bundle" key) are handled by WidgetRegistry.registerBuiltIns().
@MainActor
public final class PluginLoader {
    public static let shared = PluginLoader()
    private var loadedBundlePaths: Set<String> = []
    private init() {}

    public func loadPlugins(config: NanoConfig, registry: WidgetRegistry) {
        for (_, pluginEntry) in config.plugins {
            guard let bundlePath = pluginEntry.bundle else { continue }
            guard !loadedBundlePaths.contains(bundlePath) else { continue }
            guard let bundle = Bundle(path: bundlePath), bundle.load() else {
                ConfigLoader.shared.report(.bundleNotFound(path: bundlePath))
                continue
            }
            guard
                let cls = bundle.principalClass as? NSObject.Type,
                let entry = cls.init() as? (any NanoBarPluginEntry)
            else {
                ConfigLoader.shared.report(.invalidPrincipalClass(path: bundlePath))
                continue
            }
            entry.registerWidgets(with: RegistryBridge(inner: registry), config: pluginEntry.settings)
            loadedBundlePaths.insert(bundlePath)
        }
    }
}
