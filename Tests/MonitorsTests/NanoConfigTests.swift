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

    // MARK: - Glass tint parsing

    @Test("camelCase tint keys are decoded correctly from TOML")
    func glassConfigTintParsing() throws {
        let raw = """
            [pill.liquidGlass]
            defaultEffect = "regular"
            defaultTint = "#FF000080"
            hoverEffect = "regular"
            hoverTint = "#00FF0080"
            toggledEffect = "regular"
            toggledTint = "#0000FF80"
            """
        let config = try TOMLDecoder().decode(NanoConfig.self, from: raw)
        let glass = config.pill.liquidGlass
        #expect(glass.defaultEffect == "regular")
        #expect(glass.defaultTint   == "#FF000080")
        #expect(glass.hoverTint     == "#00FF0080")
        #expect(glass.toggledTint   == "#0000FF80")
    }

    @Test("nil defaultTint when key absent, defaults applied for hover/toggled")
    func glassConfigTintDefaults() throws {
        let raw = """
            [pill.liquidGlass]
            defaultEffect = "clear"
            """
        let config = try TOMLDecoder().decode(NanoConfig.self, from: raw)
        let glass = config.pill.liquidGlass
        #expect(glass.defaultTint   == nil)
        #expect(glass.hoverTint     == "#FFFFFF30")
        #expect(glass.toggledTint   == "#FFFFFF30")
    }

    @Test("TOMLWriter patch round-trip preserves tint hex value")
    func glassConfigWriteReadRoundTrip() throws {
        var raw = ""
        raw = TOMLWriter.patch(raw: raw, section: "pill.liquidGlass", key: "defaultTint", value: .string("#AB12CD80"))
        let config = try TOMLDecoder().decode(NanoConfig.self, from: raw)
        #expect(config.pill.liquidGlass.defaultTint == "#AB12CD80")
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
}
