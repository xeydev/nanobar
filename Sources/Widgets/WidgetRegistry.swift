import SwiftUI
import Monitors
import NanoBarKit

// MARK: - WidgetRegistry

/// Central registry mapping widget IDs to view factories.
/// Both built-in widgets and external plugins register here via the same API.
@MainActor
public final class WidgetRegistry {
    public static let shared = WidgetRegistry()
    private var factories: [String: () -> AnyView] = [:]
    private init() {}

    public func register(id: String, factory: @escaping @MainActor () -> AnyView) {
        factories[id] = factory
    }

    public func view(for id: String) -> AnyView? {
        factories[id].map { $0() }
    }

    public func clear() {
        factories.removeAll()
    }

    // MARK: Built-in registration

    /// Registers all built-in widgets using the same API as external plugins.
    /// Each built-in receives its config slice from `[plugins.<id>]`.
    public func registerBuiltIns(config: NanoConfig) {
        func cfg(_ id: String) -> [String: String] { config.plugins[id] ?? [:] }
        register(id: "clock")       { AnyView(ClockView(config: cfg("clock"))) }
        register(id: "battery")     { AnyView(BatteryView(config: cfg("battery"))) }
        register(id: "volume")      { AnyView(VolumeView(config: cfg("volume"))) }
        register(id: "keyboard")    { AnyView(KeyboardView(config: cfg("keyboard"))) }
        register(id: "now_playing") { AnyView(NowPlayingView(config: cfg("now_playing"))) }
        register(id: "workspaces")  { AnyView(WorkspaceBarView(config: cfg("workspaces"))) }
    }
}

// MARK: - RegistryBridge

/// Bridges the @objc NanoBarWidgetRegistry protocol (used by external plugins)
/// to the Swift WidgetRegistry.
/// Always called from the main thread (PluginLoader is @MainActor), so
/// MainActor.assumeIsolated is safe here.
final class RegistryBridge: NSObject, NanoBarWidgetRegistry, @unchecked Sendable {
    private let inner: WidgetRegistry
    init(inner: WidgetRegistry) { self.inner = inner }

    func register(_ factory: any NanoBarWidgetFactory) {
        let id = factory.widgetID
        let box = factory.makeViewBox()
        MainActor.assumeIsolated {
            inner.register(id: id) { box.view }
        }
    }
}
