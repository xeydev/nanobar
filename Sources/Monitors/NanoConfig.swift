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
        public var background:   String      = "none"
        public var height:       Double      = 30
        public var cornerRadius: Double      = 0
        public var shadow:       Bool        = false
        /// Gap between screen edge and bar background.
        /// Scalar (`margin = 12`) or inline table (`margin = { all = 12, top = 4 }`).
        public var margin:       SideInsets  = SideInsets()
        /// Gap between bar background edge and pill widgets.
        /// Scalar (`padding = 8`) or inline table (`padding = { all = 8, left = 12 }`).
        public var padding:      SideInsets  = SideInsets(all: 8)
        /// `false`, `true` (defaults), or `{ width = 1.0, color = "#FFFFFF59" }`.
        public var border:       BorderConfig = .disabled
        public init() {}

        private enum CodingKeys: String, CodingKey {
            case background, height, cornerRadius, shadow, margin, padding, border
        }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            background   = try c.decodeIfPresent(String.self,       forKey: .background) ?? "none"
            height       = try c.decodeDoubleOrInt(forKey: .height)                      ?? 30
            cornerRadius = try c.decodeDoubleOrInt(forKey: .cornerRadius)                ?? 0
            shadow       = try c.decodeIfPresent(Bool.self,         forKey: .shadow)     ?? false
            margin       = try c.decodeIfPresent(SideInsets.self,   forKey: .margin)     ?? SideInsets()
            padding      = try c.decodeIfPresent(SideInsets.self,   forKey: .padding)    ?? SideInsets(all: 8)
            border       = try c.decodeIfPresent(BorderConfig.self, forKey: .border)     ?? .disabled
        }
    }

    public struct PillConfig: Decodable, Sendable {
        public var shadow:        Bool         = true
        /// `false` | `true` (adaptive) | `{ width = 0.75, color = "#FFFFFF47" }`
        public var border:        BorderConfig = .auto
        /// "glass" | "thin" | "ultraThin" | "solid" | "none"
        public var material:      String       = "glass"
        public var specular:      Bool         = true
        public var cornerRadius:  Double       = 15
        public init() {}

        private enum CodingKeys: String, CodingKey { case shadow, border, material, specular, cornerRadius }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            shadow       = try c.decodeIfPresent(Bool.self,         forKey: .shadow)   ?? true
            border       = try c.decodeIfPresent(BorderConfig.self, forKey: .border)   ?? .auto
            material     = try c.decodeIfPresent(String.self,       forKey: .material) ?? "glass"
            specular     = try c.decodeIfPresent(Bool.self,         forKey: .specular) ?? true
            cornerRadius = try c.decodeDoubleOrInt(forKey: .cornerRadius)              ?? 15
        }
    }

    // MARK: Properties

    public var widgets: Widgets   = .init()
    public var bar:     BarConfig = .init()
    public var pill:    PillConfig = .init()

    /// One entry per `[plugins.<id>]` section.
    public var plugins: [String: PluginEntry] = [:]

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
        background   = "none"    # none | blur | color:#RRGGBBAA
        height       = 30
        cornerRadius = 0
        shadow       = false

        # margin: gap between screen edge and bar background
        # scalar sets all sides; inline table allows per-side overrides
        margin  = 0
        # margin = { all = 6, top = 4, bottom = 4 }

        # padding: gap between bar background edge and pill widgets
        padding = 8
        # padding = { all = 8, left = 12, right = 12 }

        # border: false | true | { width = 1.0, color = "#FFFFFF59" }
        border  = false

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

        plugins = try container.decodeIfPresent([String: PluginEntry].self, forKey: .plugins) ?? [:]
    }
}

// MARK: - SideInsets

/// Four-sided inset that decodes from either a scalar or an inline table.
///
/// ```toml
/// margin = 12                          # all sides
/// margin = { all = 12, top = 4 }      # default + per-side overrides
/// margin = { top = 4, left = 8 }      # only specified sides (others = 0)
/// ```
public struct SideInsets: Decodable, Sendable {
    public let top: Double
    public let right: Double
    public let bottom: Double
    public let left: Double

    public init(all: Double = 0) { top = all; right = all; bottom = all; left = all }

    private enum CodingKeys: String, CodingKey { case all, top, right, bottom, left }

    public init(from decoder: any Decoder) throws {
        // Scalar form: margin = 12
        if let d = try? decoder.singleValueContainer().decode(Double.self) {
            (top, right, bottom, left) = (d, d, d, d); return
        }
        if let i = try? decoder.singleValueContainer().decode(Int.self) {
            let d = Double(i); (top, right, bottom, left) = (d, d, d, d); return
        }
        // Table form: margin = { all = 12, top = 4 }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let all = try c.decodeDoubleOrInt(forKey: .all) ?? 0
        top    = try c.decodeDoubleOrInt(forKey: .top)    ?? all
        right  = try c.decodeDoubleOrInt(forKey: .right)  ?? all
        bottom = try c.decodeDoubleOrInt(forKey: .bottom) ?? all
        left   = try c.decodeDoubleOrInt(forKey: .left)   ?? all
    }
}

// MARK: - BorderConfig

/// Border that decodes from a bool or an inline table.
///
/// ```toml
/// border = false                               # disabled
/// border = true                                # auto (adaptive color, default width)
/// border = { width = 1.5, color = "#FF0000" }  # fully custom
/// ```
public enum BorderConfig: Decodable, Sendable {
    case disabled
    case auto                                  // border = true
    case custom(width: Double, color: String)  // border = { ... }

    public var isEnabled: Bool   { if case .disabled = self { return false }; return true }
    public var isAuto: Bool      { if case .auto     = self { return true  }; return false }
    public var width: Double     { if case .custom(let w, _) = self { return w }; return 0.75 }
    public var customColor: String? { if case .custom(_, let c) = self { return c }; return nil }

    private enum CodingKeys: String, CodingKey { case width, color }

    public init(from decoder: any Decoder) throws {
        if let b = try? decoder.singleValueContainer().decode(Bool.self) {
            self = b ? .auto : .disabled; return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let width = try c.decodeDoubleOrInt(forKey: .width) ?? 0.75
        let color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#FFFFFF59"
        self = .custom(width: width, color: color)
    }
}

// MARK: - PluginEntry

/// One `[plugins.<id>]` section: widget settings, optional pill override, optional bundle path.
///
/// All string keys other than `pill` and `bundle` go into `settings`.
/// ```toml
/// [plugins.clock]
/// format = "HH:mm"
/// color  = "#FF7EB6"
///
/// [plugins.clock.pill]
/// cornerRadius = 20
/// border       = { color = "#FF7EB6" }
/// ```
public struct PluginEntry: Decodable, Sendable {
    public var settings: [String: String]    = [:]
    public var pill:     NanoConfig.PillConfig? = nil
    public var bundle:   String?             = nil
    public init() {}

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        for key in c.allKeys {
            switch key.stringValue {
            case "bundle": bundle = try? c.decode(String.self,             forKey: key)
            case "pill":   pill   = try? c.decode(NanoConfig.PillConfig.self, forKey: key)
            default:
                if let s = try? c.decode(String.self, forKey: key) { settings[key.stringValue] = s }
            }
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
