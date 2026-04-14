import SwiftUI

/// Version of the NanoBarKit API. Plugins built against an incompatible version will be rejected.
public let NanoBarKitVersion: Int = 1

// MARK: - Plugin entry point

/// Implement this protocol in your plugin bundle's principal class.
/// Set `NSPrincipalClass` in the bundle's Info.plist to the fully-qualified class name.
/// Uses Objective-C ABI for stability across Swift versions.
@objc public protocol NanoBarPluginEntry: NSObjectProtocol {
    /// Matches the `[plugins.<pluginID>]` TOML section key, e.g. `"battery"`.
    /// Used by the host to look up config before calling `registerWidgets`.
    @objc var pluginID: String { get }

    /// Called on every config load/reload. Register (or re-register) your widgets.
    /// - Parameters:
    ///   - registry: The registry to register widget factories with.
    ///   - config: All key-value pairs from the `[plugins.<pluginID>]` TOML section.
    @MainActor @objc func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String])
}

// MARK: - Registry

/// The registry provided to plugins at load time.
@objc public protocol NanoBarWidgetRegistry: NSObjectProtocol {
    /// Register a widget factory. The factory's `widgetID` must match the `[plugins.<id>]`
    /// section name used in `config.toml`.
    @MainActor @objc func register(_ factory: any NanoBarWidgetFactory)
}

// MARK: - Widget factory

/// A factory that creates the SwiftUI view for a plugin widget.
@objc public protocol NanoBarWidgetFactory: NSObjectProtocol {
    /// Stable identifier matching the `[plugins.<id>]` TOML section name.
    @objc var widgetID: String { get }

    /// Called once on the main thread when the widget is first needed.
    /// Return your SwiftUI view wrapped in a `NanoBarViewBox`.
    @MainActor @objc func makeViewBox() -> NanoBarViewBox
}

// MARK: - View box

/// Carries a SwiftUI `AnyView` across the plugin bundle boundary.
public final class NanoBarViewBox: NSObject, @unchecked Sendable {
    public let view: AnyView
    public init(_ view: AnyView) { self.view = view }
}
