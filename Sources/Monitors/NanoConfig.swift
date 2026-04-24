import Foundation
import TOMLKit

// MARK: - AppTheme

/// Controls the app-wide color scheme. Persisted as `theme` under `[app]` in config.toml.
public enum AppTheme: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

// MARK: - Config model

/// The full NanoBar configuration decoded from ~/.config/nanobar/config.toml.
public struct NanoConfig: Decodable, Sendable {

    // MARK: Nested types

    public struct AppConfig: Decodable, Sendable {
        /// "system" | "light" | "dark"
        public var theme: String = "system"
        public init() {}

        private enum CodingKeys: String, CodingKey { case theme }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? "system"
        }
    }

    public struct Widgets: Decodable, Sendable {
        public var left:   [String] = ["workspaces"]
        public var center: [String] = ["now_playing"]
        public var right:  [String] = ["keyboard", "volume", "battery", "clock"]
        public init() {}
    }

    public struct BarConfig: Decodable, Sendable {
        /// "none" | "blur" | "color:#RRGGBBAA"
        public var background:   String      = "none"
        public var minHeight:    Double      = 30
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
            case background, minHeight, cornerRadius, shadow, margin, padding, border
        }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            background   = try c.decodeIfPresent(String.self,       forKey: .background) ?? "none"
            minHeight    = try c.decodeDoubleOrInt(forKey: .minHeight)                   ?? 30
            cornerRadius = try c.decodeDoubleOrInt(forKey: .cornerRadius)                ?? 0
            shadow       = try c.decodeIfPresent(Bool.self,         forKey: .shadow)     ?? false
            margin       = try c.decodeIfPresent(SideInsets.self,   forKey: .margin)     ?? SideInsets()
            padding      = try c.decodeIfPresent(SideInsets.self,   forKey: .padding)    ?? SideInsets(all: 8)
            border       = try c.decodeIfPresent(BorderConfig.self, forKey: .border)     ?? .disabled
        }
    }

    public struct PillConfig: Decodable, Sendable, Equatable {
        /// "liquidGlass" | "blur" | "solid" | "none"
        public var style:        String       = "liquidGlass"
        public var height:       Double       = 30
        public var cornerRadius: Double       = 15
        /// `false` | `true` (adaptive) | `{ width = 0.75, color = "#FFFFFF47" }`
        public var border:       BorderConfig = .auto
        /// Options for the liquidGlass style (ignored for blur/solid/none).
        public var liquidGlass:  GlassConfig  = .init()
        /// Options for the blur style (ignored for other styles).
        public var blur:         BlurConfig   = .init()
        /// Fill color for the solid style, e.g. `"#1C1C1ECC"`. Ignored for other styles.
        public var solidColor:   String       = "#1C1C1ECC"
        /// Whether to show a drop shadow in the solid style.
        public var solidShadow:  Bool         = false
        public init() {}

        private enum CodingKeys: String, CodingKey {
            case style, height, cornerRadius, border, liquidGlass, blur, solidColor, solidShadow
        }
        public init(from decoder: any Decoder) throws {
            let c    = try decoder.container(keyedBy: CodingKeys.self)
            style        = try c.decodeIfPresent(String.self,       forKey: .style)       ?? "liquidGlass"
            height       = try c.decodeDoubleOrInt(forKey: .height)                       ?? 30
            cornerRadius = try c.decodeDoubleOrInt(forKey: .cornerRadius)                 ?? 15
            border       = try c.decodeIfPresent(BorderConfig.self, forKey: .border)      ?? .auto
            liquidGlass  = try c.decodeIfPresent(GlassConfig.self,  forKey: .liquidGlass) ?? .init()
            blur         = try c.decodeIfPresent(BlurConfig.self,   forKey: .blur)        ?? .init()
            solidColor   = try c.decodeIfPresent(String.self,       forKey: .solidColor)  ?? "#1C1C1ECC"
            solidShadow  = try c.decodeIfPresent(Bool.self,         forKey: .solidShadow) ?? false
        }
    }

    // MARK: - GlassConfig

    public struct GlassConfig: Decodable, Sendable, Equatable {
        /// Effect at rest: "regular" | "clear" | "identity"
        public var defaultEffect: String  = "clear"
        /// Effect on hover.
        public var hoverEffect:   String  = "regular"
        /// Effect when focused/toggled (e.g. active workspace).
        public var toggledEffect: String  = "regular"
        /// Pre-macOS 26 fallback appearance (ignored on macOS 26+).
        public var blur:          BlurConfig = .init()
        public init() {}

        private enum CodingKeys: String, CodingKey {
            case defaultEffect, hoverEffect, toggledEffect, blur
        }
        public init(from decoder: any Decoder) throws {
            let c        = try decoder.container(keyedBy: CodingKeys.self)
            defaultEffect = try c.decodeIfPresent(String.self,     forKey: .defaultEffect) ?? "clear"
            hoverEffect   = try c.decodeIfPresent(String.self,     forKey: .hoverEffect)   ?? "regular"
            toggledEffect = try c.decodeIfPresent(String.self,     forKey: .toggledEffect) ?? "regular"
            blur          = try c.decodeIfPresent(BlurConfig.self,  forKey: .blur)          ?? .init()
        }
    }

    // MARK: - BlurConfig

    /// Pre-macOS 26 blur fallback for the liquidGlass style.
    public struct BlurConfig: Decodable, Sendable, Equatable {
        /// "regular" | "thin" | "ultraThin"
        public var material: String = "regular"
        /// White gradient overlay to simulate specular highlight.
        public var specular: Bool   = true
        /// Manual drop shadow (macOS 26 glass manages its own shadow).
        public var shadow:   Bool   = true
        public init() {}

        private enum CodingKeys: String, CodingKey { case material, specular, shadow }
        public init(from decoder: any Decoder) throws {
            let c    = try decoder.container(keyedBy: CodingKeys.self)
            material = try c.decodeIfPresent(String.self, forKey: .material) ?? "regular"
            specular = try c.decodeIfPresent(Bool.self,   forKey: .specular) ?? true
            shadow   = try c.decodeIfPresent(Bool.self,   forKey: .shadow)   ?? true
        }
    }

    // MARK: Properties

    public var app:     AppConfig  = .init()
    public var widgets: Widgets    = .init()
    public var bar:     BarConfig  = .init()
    public var pill:    PillConfig = .init()

    /// One entry per `[plugins.<id>]` section.
    public var plugins: [String: PluginEntry] = [:]

    /// Parsed `app.theme` string. Falls back to `.system` for unrecognized values.
    public var resolvedTheme: AppTheme {
        AppTheme(rawValue: app.theme) ?? .system
    }

    // MARK: Defaults

    public static let defaults = NanoConfig()

    // MARK: Default TOML template

    public static let defaultTOML = """
        [widgets]
        left   = ["workspaces"]
        center = ["now_playing"]
        right  = ["keyboard", "volume", "battery", "clock"]

        # ─── Bar appearance ───────────────────────────────────────────────────────────
        # Uncomment and edit any key to override its default value.

        # [bar]
        # background   = "none"    # none | blur | color:#RRGGBBAA
        # minHeight    = 30
        # cornerRadius = 0
        # shadow       = false
        #
        # # margin: gap between screen edge and bar background
        # # scalar sets all sides; inline table allows per-side overrides
        # margin  = 0
        # # margin = { all = 6, top = 4, bottom = 4 }
        #
        # # padding: gap between bar background edge and pill widgets
        # padding = 8
        # # padding = { all = 8, left = 12, right = 12 }
        #
        # # border: false | true | { width = 1.0, color = "#FFFFFF59" }
        # border  = false

        # ─── Pill appearance ──────────────────────────────────────────────────────────

        # [pill]
        # style        = "liquidGlass"   # liquidGlass | solid | none
        # height       = 30
        # cornerRadius = 15
        # border       = true            # false | true | { width = 0.75, color = "#FFFFFF47" }

        # [pill.liquidGlass]
        # # Glass effect for each interaction state: "regular" | "clear" | "identity"
        # defaultEffect = "clear"
        # hoverEffect   = "regular"
        # toggledEffect = "regular"

        # [pill.liquidGlass.blur]
        # # Pre-macOS 26 fallback — ignored on macOS 26+ (glass handles itself).
        # material = "regular"   # regular | thin | ultraThin
        # specular = true        # white gradient overlay
        # shadow   = true        # macOS 26 glass manages its own shadow

        # ─── Standard plugin settings (optional overrides) ────────────────────────────
        # Standard plugins are auto-loaded from the Plugins/ directory — no bundle
        # path needed. Add a section only to override defaults.

        # [plugins.clock]
        # format = "EEE dd MMM HH:mm"
        # color  = "#FF7EB6"

        # [plugins.battery]
        # color     = "#B5EAD7"
        # warnColor = "#FFD1A8"
        # medColor  = "#FEFAC1"
        # lowColor  = "#FFB3BF"

        # [plugins.volume]
        # color = "#AEC6CF"

        # [plugins.keyboard]
        # color = "#DDB6F2"

        # [plugins.workspaces]
        # mode = "clampAndExpand"  # labelsOnly | activeIcons | clampAndExpand

        # [plugins.now_playing]
        # activeColor = "#B5EAD7"

        # ─── Third-party plugins ──────────────────────────────────────────────────────
        # Custom plugins require an explicit bundle path.
        #
        # [plugins.myplugin]
        # bundle = "/path/to/MyPlugin.bundle"
        # color  = "#AEC6CF"
        """

    // MARK: Decodable

    // Manual CodingKeys to map TOML structure to Swift model.
    private enum CodingKeys: String, CodingKey {
        case app, widgets, bar, pill, plugins
    }

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        app     = try container.decodeIfPresent(AppConfig.self, forKey: .app)   ?? .init()
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
public struct SideInsets: Decodable, Sendable, Equatable {
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
public enum BorderConfig: Decodable, Sendable, Equatable {
    case disabled
    case auto                                  // border = true
    case custom(width: Double, color: String)  // border = { ... }

    public static let defaultColor = "#FFFFFF59"

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
        let color = try c.decodeIfPresent(String.self, forKey: .color) ?? BorderConfig.defaultColor
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
