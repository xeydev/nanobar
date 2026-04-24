import SwiftUI

// MARK: - Settings schema types

/// A single configurable field declared by a plugin for display in the Settings UI.
public struct SettingsField: Sendable {
    public let key: String
    public let label: String
    public let type: FieldType
    /// TOML-compatible default value string (e.g. `"#FFFFFF"`, `"25"`, `"true"`).
    /// For `.color` fields with adaptive defaults, pass `""` here and supply `adaptiveColor`.
    public let defaultValue: String
    /// For `.color` fields: the live adaptive `Theme` color shown in the picker when no
    /// custom value is set. Stored as `""` in config; the factory falls back to this Color
    /// at render time so it re-resolves on every theme change.
    /// Nil for non-color fields or color fields with a fixed default.
    public let adaptiveColor: Color?

    public init(key: String, label: String, type: FieldType, defaultValue: String, adaptiveColor: Color? = nil) {
        self.key = key
        self.label = label
        self.type = type
        self.defaultValue = defaultValue
        self.adaptiveColor = adaptiveColor
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

public extension NanoBarPluginSettingsProvider {
    /// Merge schema defaults into a raw config dict so factories always receive every key.
    ///
    /// Keys present in `raw` are preserved as-is. Keys absent from `raw` are filled with
    /// the `defaultValue` from the matching ``SettingsField``. Extra keys in `raw` that have
    /// no corresponding field are passed through unchanged.
    ///
    /// This is the single source of truth for plugin default values — factories call this
    /// and can then safely force-unwrap `config["key"]` without carrying duplicate fallbacks.
    func resolvedSettings(_ raw: [String: String]) -> [String: String] {
        var resolved = raw
        for field in settingsSchema() where resolved[field.key] == nil {
            resolved[field.key] = field.defaultValue
        }
        return resolved
    }
}
