import Foundation
import TOMLKit

// MARK: - Config model

/// The full NanoBar configuration decoded from ~/.config/nanobar/config.toml.
public struct NanoConfig: Decodable, Sendable {

    // MARK: Nested types

    public struct Widgets: Decodable, Sendable {
        public var left:   [String] = ["workspaces"]
        public var center: [String] = ["now_playing"]
        public var right:  [String] = ["keyboard", "volume", "battery", "clock"]
        public init() {}
    }

    public struct BarConfig: Decodable, Sendable {
        /// "none" | "blur" | "color:#RRGGBBAA"
        public var background: String  = "none"
        public var height:     Double  = 30
        public init() {}

        private enum CodingKeys: String, CodingKey { case background, height }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            background = try c.decodeIfPresent(String.self, forKey: .background) ?? "none"
            height     = try c.decodeDoubleOrInt(forKey: .height) ?? 30
        }
    }

    public struct PillConfig: Decodable, Sendable {
        public var shadow:        Bool   = true
        public var border:        Bool   = true
        /// "glass" | "thin" | "ultraThin" | "solid" | "none"
        public var material:      String = "glass"
        public var specular:      Bool   = true
        public var cornerRadius:  Double = 15
        public init() {}

        private enum CodingKeys: String, CodingKey { case shadow, border, material, specular, cornerRadius }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            shadow       = try c.decodeIfPresent(Bool.self,   forKey: .shadow)   ?? true
            border       = try c.decodeIfPresent(Bool.self,   forKey: .border)   ?? true
            material     = try c.decodeIfPresent(String.self, forKey: .material) ?? "glass"
            specular     = try c.decodeIfPresent(Bool.self,   forKey: .specular) ?? true
            cornerRadius = try c.decodeDoubleOrInt(forKey: .cornerRadius) ?? 15
        }
    }

    // MARK: Properties

    public var widgets: Widgets   = .init()
    public var bar:     BarConfig = .init()
    public var pill:    PillConfig = .init()

    /// All plugin config sections (built-in and external) keyed by plugin ID.
    /// External plugins have a "bundle" key; built-ins do not.
    public var plugins: [String: [String: String]] = [:]

    // MARK: Defaults

    public static let defaults = NanoConfig()

    // MARK: Default TOML template

    public static let defaultTOML = """
        [widgets]
        left   = ["workspaces"]
        center = ["now_playing"]
        right  = ["keyboard", "volume", "battery", "clock"]

        # ─── Bar appearance ───────────────────────────────────────────────────────────

        [bar]
        background = "none"      # none | blur | color:#RRGGBBAA
        height     = 30

        # ─── Pill appearance ──────────────────────────────────────────────────────────

        [pill]
        shadow       = true
        border       = true
        material     = "glass"   # glass | thin | ultraThin | solid | none
        specular     = true
        cornerRadius = 15

        # ─── Built-in widget config (all sections are optional) ───────────────────────

        [plugins.clock]
        format = "EEE dd MMM HH:mm"
        color  = "#FF7EB6"

        [plugins.battery]
        color     = "#B5EAD7"
        warnColor = "#FFD1A8"
        medColor  = "#FEFAC1"
        lowColor  = "#FFB3BF"

        [plugins.volume]
        color = "#AEC6CF"

        [plugins.keyboard]
        color = "#DDB6F2"

        [plugins.now_playing]
        activeColor = "#B5EAD7"

        [plugins.workspaces]
        mode = "clampAndExpand"  # labelsOnly | activeIcons | clampAndExpand

        # ─── External plugins ─────────────────────────────────────────────────────────
        # Presence of "bundle" key (absolute path) marks this as an external plugin.
        # All other keys are forwarded to the plugin as [String: String].
        #
        # [plugins.mywidget]
        # bundle = "/path/to/MyWidget.bundle"
        # color  = "#AEC6CF"
        """

    // MARK: Decodable

    // Manual CodingKeys to map TOML structure to Swift model.
    private enum CodingKeys: String, CodingKey {
        case widgets, bar, pill, plugins
    }

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        widgets = try container.decodeIfPresent(Widgets.self, forKey: .widgets) ?? .init()
        bar     = try container.decodeIfPresent(BarConfig.self, forKey: .bar)   ?? .init()
        pill    = try container.decodeIfPresent(PillConfig.self, forKey: .pill) ?? .init()

        // plugins is [String: [String: String]] — decode as dict-of-dicts
        if let rawPlugins = try container.decodeIfPresent(
            [String: [String: String]].self, forKey: .plugins
        ) {
            plugins = rawPlugins
        }
    }
}

// MARK: - Decoding helper

private extension KeyedDecodingContainer {
    /// Decodes a Double, accepting TOML integers (which TOMLKit won't auto-coerce to Double).
    func decodeDoubleOrInt(forKey key: Key) throws -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? decodeIfPresent(Int.self,    forKey: key) { return Double(i) }
        return nil
    }
}
