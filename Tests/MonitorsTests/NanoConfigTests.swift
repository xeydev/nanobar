import Testing
import TOMLKit
@testable import Monitors

@Suite("NanoConfig")
struct NanoConfigTests {

    // MARK: - Pill override toggle bug regression

    /// Regression test for: pill override toggle always snapping back to ON after being disabled.
    ///
    /// Root cause: `removeSection("plugins.x.pill")` left `[plugins.x.pill.liquidGlass]` in the
    /// file. TOMLKit infers a parent table from any child section header, so
    /// `config.plugins["x"]?.pill` was non-nil even without an explicit `[plugins.x.pill]` line,
    /// causing `onReceive` to set the toggle back to `true`.
    @Test("orphaned liquidGlass subsection causes pill to decode as non-nil")
    func orphanedLiquidGlassCausesPillNonNil() throws {
        // Simulate the state left by removeSection("plugins.clock.pill") alone:
        // parent [plugins.clock.pill] is gone, child [plugins.clock.pill.liquidGlass] survives.
        let raw = """
            [plugins.clock]
            format = "%H:%M"

            [plugins.clock.pill.liquidGlass]
            defaultEffect = "regular"
            """
        let config = try TOMLDecoder().decode(NanoConfig.self, from: raw)
        // TOMLKit infers plugins.clock.pill as a non-nil table → toggle snaps back to ON.
        #expect(config.plugins["clock"]?.pill != nil)
    }

    // MARK: - Glass effect parsing

    @Test("glass effect keys are decoded correctly from TOML")
    func glassConfigEffectParsing() throws {
        let raw = """
            [pill.liquidGlass]
            defaultEffect = "regular"
            hoverEffect   = "identity"
            toggledEffect = "clear"
            """
        let config = try TOMLDecoder().decode(NanoConfig.self, from: raw)
        let glass = config.pill.liquidGlass
        #expect(glass.defaultEffect == "regular")
        #expect(glass.hoverEffect   == "identity")
        #expect(glass.toggledEffect == "clear")
    }

    @Test("glass effect defaults applied when keys absent")
    func glassConfigEffectDefaults() throws {
        let raw = "[pill.liquidGlass]\n"
        let config = try TOMLDecoder().decode(NanoConfig.self, from: raw)
        let glass = config.pill.liquidGlass
        #expect(glass.defaultEffect == "clear")
        #expect(glass.hoverEffect   == "regular")
        #expect(glass.toggledEffect == "regular")
    }

    /// Removing all three pill section levels (deepest-first) correctly leaves pill == nil.
    @Test("removeSectionTree removes all pill levels leaving pill nil")
    func removeSectionTreeMakesPillNil() throws {
        let raw = """
            [plugins.clock]
            format = "%H:%M"

            [plugins.clock.pill]
            style = "solid"

            [plugins.clock.pill.liquidGlass]
            defaultEffect = "regular"

            [plugins.clock.pill.liquidGlass.blur]
            material = "thin"
            """
        let section = "plugins.clock.pill"
        let glassSection = "\(section).liquidGlass"
        var result = TOMLWriter.removeSection(raw: raw, section: "\(glassSection).blur")
        result = TOMLWriter.removeSection(raw: result, section: glassSection)
        result = TOMLWriter.removeSection(raw: result, section: section)

        let config = try TOMLDecoder().decode(NanoConfig.self, from: result)
        #expect(config.plugins["clock"]?.pill == nil)
        // Plugin's own settings are preserved.
        #expect(config.plugins["clock"]?.settings["format"] == "%H:%M")
    }

    // MARK: - Theme config

    @Test("theme defaults to system when [app] section absent")
    func themeDefaultsToSystem() throws {
        let config = try TOMLDecoder().decode(NanoConfig.self, from: "")
        #expect(config.app.theme == "system")
    }

    @Test("theme = light decoded from [app] section")
    func themeLightDecoded() throws {
        let raw = "[app]\ntheme = \"light\""
        let config = try TOMLDecoder().decode(NanoConfig.self, from: raw)
        #expect(config.app.theme == "light")
    }

    @Test("theme = dark decoded from [app] section")
    func themeDarkDecoded() throws {
        let raw = "[app]\ntheme = \"dark\""
        let config = try TOMLDecoder().decode(NanoConfig.self, from: raw)
        #expect(config.app.theme == "dark")
    }

    @Test("resolvedTheme returns .system for default config")
    func resolvedThemeDefault() {
        let config = NanoConfig()
        #expect(config.resolvedTheme == .system)
    }

    @Test("resolvedTheme returns .light when theme string is light")
    func resolvedThemeLight() {
        var config = NanoConfig()
        config.app.theme = "light"
        #expect(config.resolvedTheme == .light)
    }

    @Test("resolvedTheme returns .dark when theme string is dark")
    func resolvedThemeDark() {
        var config = NanoConfig()
        config.app.theme = "dark"
        #expect(config.resolvedTheme == .dark)
    }

    @Test("resolvedTheme falls back to .system for unrecognized string")
    func resolvedThemeFallback() {
        var config = NanoConfig()
        config.app.theme = "sepia"
        #expect(config.resolvedTheme == .system)
    }
}
