import SwiftUI
import NanoBarPluginAPI

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
}

// MARK: - RegistryBridge

/// Bridges the @objc NanoBarWidgetRegistry protocol (used by external plugins)
/// to the Swift WidgetRegistry.
final class RegistryBridge: NSObject, NanoBarWidgetRegistry, @unchecked Sendable {
    private let inner: WidgetRegistry
    init(inner: WidgetRegistry) { self.inner = inner }

    @MainActor func register(_ factory: any NanoBarWidgetFactory) {
        let id  = factory.widgetID
        let box = factory.makeViewBox()
        inner.register(id: id) { box.view }
    }
}
