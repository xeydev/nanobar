import SwiftUI

/// Version of the NanoBarKit API. Plugins built against an incompatible version will be rejected.
public let NanoBarKitVersion: Int = 1

// MARK: - Plugin entry point

/// Implement this protocol in your plugin bundle's principal class.
/// Set `NSPrincipalClass` in the bundle's Info.plist to the fully-qualified class name.
/// Uses Objective-C ABI for stability across Swift versions.
@objc public protocol NanoBarPluginEntry: NSObjectProtocol {
    /// Called once when the bundle is loaded. Register your widgets using the registry.
    /// - Parameters:
    ///   - registry: The registry to register widget factories with.
    ///   - config: All key-value pairs from the `[plugins.yourID]` TOML section, excluding `bundle`.
    @objc func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String])
}

// MARK: - Registry

/// The registry provided to plugins at load time.
@objc public protocol NanoBarWidgetRegistry: NSObjectProtocol {
    /// Register a widget factory. The factory's `widgetID` must match the `[plugins.<id>]`
    /// section name used in `config.toml`.
    @objc func register(_ factory: any NanoBarWidgetFactory)
}

// MARK: - Widget factory

/// A factory that creates the SwiftUI view for a plugin widget.
@objc public protocol NanoBarWidgetFactory: NSObjectProtocol {
    /// Stable identifier matching the `[plugins.<id>]` TOML section name.
    @objc var widgetID: String { get }

    /// Called once on the main thread when the widget is first needed.
    /// Return your SwiftUI view wrapped in a `NanoBarViewBox`.
    @objc func makeViewBox() -> NanoBarViewBox
}

// MARK: - View box

/// Carries a SwiftUI `AnyView` across the plugin bundle boundary.
public final class NanoBarViewBox: NSObject, @unchecked Sendable {
    public let view: AnyView
    public init(_ view: AnyView) { self.view = view }
}
