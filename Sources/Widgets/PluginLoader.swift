import Foundation
import Monitors
import NanoBarKit

// MARK: - PluginLoader

/// Scans plugin entries in config and loads any that have a "bundle" key.
/// Built-in plugin sections (no "bundle" key) are handled by WidgetRegistry.registerBuiltIns().
@MainActor
public final class PluginLoader {
    public static let shared = PluginLoader()
    private init() {}

    public func loadPlugins(config: NanoConfig, registry: WidgetRegistry) {
        for (id, pluginConfig) in config.plugins {
            guard let bundlePath = pluginConfig["bundle"] else {
                // No bundle key → built-in, already registered
                continue
            }
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
            let userConfig = pluginConfig.filter { $0.key != "bundle" }
            let bridge = RegistryBridge(inner: registry)
            entry.registerWidgets(with: bridge, config: userConfig)
            _ = id  // used for error context above; suppress unused warning
        }
    }
}
