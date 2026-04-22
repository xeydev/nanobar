// MARK: - Settings schema types

/// A single configurable field declared by a plugin for display in the Settings UI.
public struct SettingsField: Sendable {
    public let key: String
    public let label: String
    public let type: FieldType
    /// TOML-compatible default value string (e.g. `"#FFFFFF"`, `"25"`, `"true"`).
    public let defaultValue: String

    public init(key: String, label: String, type: FieldType, defaultValue: String) {
        self.key = key
        self.label = label
        self.type = type
        self.defaultValue = defaultValue
    }
}

/// The UI control type for a ``SettingsField``.
public enum FieldType: Sendable {
    /// Free-form text input.
    case text
    /// Color well — value stored as `"#RRGGBBAA"` hex string.
    case color
    /// Boolean toggle — value stored as `"true"` or `"false"`.
    case toggle
    /// Fixed-option picker.
    case picker(options: [PickerOption])
    /// Numeric stepper with inclusive min/max and step size.
    case stepper(min: Double, max: Double, step: Double)
}

/// One option inside a ``FieldType/picker(options:)`` field.
public struct PickerOption: Sendable {
    /// Raw value written to TOML on selection.
    public let value: String
    /// Human-readable label shown in the UI.
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

// MARK: - Settings provider protocol

/// Plugins conform to this protocol (in addition to ``NanoBarPluginEntry``) to expose
/// their configurable settings to the NanoBar Settings UI.
///
/// The host discovers conforming plugins at load time via a protocol cast:
/// ```swift
/// if let provider = entry as? any NanoBarPluginSettingsProvider {
///     schemas.append((id: entry.pluginID, provider: provider))
/// }
/// ```
public protocol NanoBarPluginSettingsProvider {
    /// Human-readable plugin name shown as the Settings tab title.
    var displayName: String { get }

    /// Ordered list of configurable fields. The Settings UI generates one row per field.
    func settingsSchema() -> [SettingsField]
}
