import Testing
@testable import Monitors

@Suite("TOMLWriter")
struct TOMLWriterTests {

    // MARK: - String values

    @Test("patches existing string key")
    func patchExistingString() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\ncolor = \"#FF0000\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock", key: "format", value: .string("EEE HH:mm"))
        #expect(result.contains("format = \"EEE HH:mm\""))
        #expect(result.contains("color = \"#FF0000\""))
    }

    @Test("inserts new string key into existing section")
    func insertNewString() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock", key: "color", value: .string("#FF0000"))
        #expect(result.contains("color = \"#FF0000\""))
        #expect(result.contains("format = \"HH:mm\""))
    }

    @Test("creates missing section with key")
    func createsMissingSection() {
        let raw = "[plugins.battery]\ncolor = \"#00FF00\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock", key: "format", value: .string("HH:mm"))
        #expect(result.contains("[plugins.clock]"))
        #expect(result.contains("format = \"HH:mm\""))
        #expect(result.contains("[plugins.battery]"))
        #expect(result.contains("color = \"#00FF00\""))
    }

    // MARK: - Non-string values

    @Test("patches integer value without quotes")
    func patchInteger() {
        let raw = "[bar]\nheight = 30\n"
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "height", value: .integer(40))
        #expect(result.contains("height = 40"))
        #expect(!result.contains("height = \"40\""))
    }

    @Test("patches double value without quotes")
    func patchDouble() {
        let raw = "[bar]\ncornerRadius = 0.0\n"
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "cornerRadius", value: .double(8.5))
        #expect(result.contains("cornerRadius = 8.5"))
    }

    @Test("patches bool false")
    func patchBoolFalse() {
        let raw = "[bar]\nshadow = true\n"
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "shadow", value: .bool(false))
        #expect(result.contains("shadow = false"))
    }

    @Test("patches bool true")
    func patchBoolTrue() {
        let raw = "[bar]\nshadow = false\n"
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "shadow", value: .bool(true))
        #expect(result.contains("shadow = true"))
    }

    // MARK: - Comment preservation

    @Test("preserves comments in file")
    func preservesComments() {
        let raw = "# Top comment\n[plugins.clock]\n# field comment\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock", key: "format", value: .string("EEE"))
        #expect(result.contains("# Top comment"))
        #expect(result.contains("# field comment"))
    }

    @Test("preserves other sections when patching")
    func preservesOtherSections() {
        let raw = "[bar]\nheight = 30\n\n[pill]\nstyle = \"liquidGlass\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "height", value: .integer(40))
        #expect(result.contains("[pill]"))
        #expect(result.contains("style = \"liquidGlass\""))
    }

    // MARK: - Nested section paths

    @Test("creates nested section plugins.clock.pill")
    func nestedSection() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock.pill", key: "style", value: .string("solid"))
        #expect(result.contains("[plugins.clock.pill]"))
        #expect(result.contains("style = \"solid\""))
        #expect(result.contains("format = \"HH:mm\""))
    }

    @Test("patches existing nested section")
    func patchExistingNestedSection() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n\n[plugins.clock.pill]\nstyle = \"solid\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock.pill", key: "style", value: .string("none"))
        #expect(result.contains("style = \"none\""))
        #expect(result.contains("format = \"HH:mm\""))
    }

    // MARK: - Key matching edge cases

    @Test("matches key even with extra whitespace in source")
    func keyWithExtraWhitespace() {
        let raw = "[bar]\nheight   =   30\n"
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "height", value: .integer(40))
        #expect(result.contains("height = 40"))
    }

    @Test("does not match key that is a prefix of another key")
    func noPartialKeyMatch() {
        let raw = "[plugins.battery]\ncolor = \"#FF0000\"\nwarnColor = \"#FFAA00\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.battery", key: "color", value: .string("#00FF00"))
        #expect(result.contains("color = \"#00FF00\""))
        #expect(result.contains("warnColor = \"#FFAA00\""))
    }

    // MARK: - String escaping

    @Test("escapes backslash in string values")
    func escapesBackslash() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock", key: "format", value: .string("a\\b"))
        #expect(result.contains("format = \"a\\\\b\""))
    }

    @Test("escapes double-quote in string values")
    func escapesDoubleQuote() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock", key: "format", value: .string("say \"hi\""))
        #expect(result.contains("format = \"say \\\"hi\\\"\""))
    }

    @Test("string with no special chars needs no escaping")
    func noEscapeNeeded() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock", key: "format", value: .string("EEE dd MMM HH:mm"))
        #expect(result.contains("format = \"EEE dd MMM HH:mm\""))
    }

    // MARK: - rawLiteral

    @Test("rawLiteral writes value as-is without quoting")
    func rawLiteralNoQuoting() {
        let raw = "[bar]\nmargin = 0\n"
        let literal = "{ top = 4, right = 8, bottom = 4, left = 8 }"
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "margin", value: .rawLiteral(literal))
        #expect(result.contains("margin = { top = 4, right = 8, bottom = 4, left = 8 }"))
        #expect(!result.contains("margin = \""))
    }

    @Test("rawLiteral creates new section with raw value")
    func rawLiteralNewSection() {
        let raw = ""
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "border", value: .rawLiteral("{ width = 1.5, color = \"#FF0000\" }"))
        #expect(result.contains("[bar]"))
        #expect(result.contains("border = { width = 1.5, color = \"#FF0000\" }"))
    }

    // MARK: - removeSection

    @Test("removes section header and content lines")
    func removeSectionBasic() {
        let raw = "[bar]\nheight = 30\n\n[pill]\nstyle = \"liquidGlass\"\n"
        let result = TOMLWriter.removeSection(raw: raw, section: "bar")
        #expect(!result.contains("[bar]"))
        #expect(!result.contains("height = 30"))
        #expect(result.contains("[pill]"))
        #expect(result.contains("style = \"liquidGlass\""))
    }

    @Test("no-op when section not found")
    func removeSectionNotFound() {
        let raw = "[bar]\nheight = 30\n"
        let result = TOMLWriter.removeSection(raw: raw, section: "pill")
        #expect(result == raw)
    }

    @Test("removes last section in file")
    func removeSectionLast() {
        let raw = "[bar]\nheight = 30\n\n[pill]\nstyle = \"liquidGlass\"\n"
        let result = TOMLWriter.removeSection(raw: raw, section: "pill")
        #expect(!result.contains("[pill]"))
        #expect(!result.contains("style = \"liquidGlass\""))
        #expect(result.contains("[bar]"))
    }

    @Test("removes only the target section when multiple exist")
    func removeSectionTargetOnly() {
        let raw = "[bar]\nheight = 30\n\n[pill]\nstyle = \"solid\"\n\n[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.removeSection(raw: raw, section: "pill")
        #expect(result.contains("[bar]"))
        #expect(result.contains("height = 30"))
        #expect(!result.contains("[pill]"))
        #expect(!result.contains("style = \"solid\""))
        #expect(result.contains("[plugins.clock]"))
        #expect(result.contains("format = \"HH:mm\""))
    }

    @Test("cleans up double blank lines after removal")
    func removeSectionNodoubleBlanks() {
        let raw = "[bar]\nheight = 30\n\n\n[pill]\nstyle = \"solid\"\n\n[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.removeSection(raw: raw, section: "pill")
        #expect(!result.contains("\n\n\n"))
    }

    // MARK: - stringArray

    @Test("writes string array with quoted elements")
    func stringArrayBasic() {
        let raw = "[widgets]\nleft = [\"clock\"]\n"
        let result = TOMLWriter.patch(raw: raw, section: "widgets", key: "left",
                                      value: .stringArray(["keyboard", "volume", "battery"]))
        #expect(result.contains("left = [\"keyboard\", \"volume\", \"battery\"]"))
    }

    @Test("writes empty string array as []")
    func stringArrayEmpty() {
        let raw = "[widgets]\ncenter = [\"now_playing\"]\n"
        let result = TOMLWriter.patch(raw: raw, section: "widgets", key: "center",
                                      value: .stringArray([]))
        #expect(result.contains("center = []"))
    }

    @Test("creates new section with array value")
    func stringArrayNewSection() {
        let raw = "[bar]\nheight = 30\n"
        let result = TOMLWriter.patch(raw: raw, section: "widgets", key: "right",
                                      value: .stringArray(["clock", "battery"]))
        #expect(result.contains("[widgets]"))
        #expect(result.contains("right = [\"clock\", \"battery\"]"))
    }

    @Test("single-element array keeps square brackets")
    func stringArraySingle() {
        let raw = "[widgets]\nleft = []\n"
        let result = TOMLWriter.patch(raw: raw, section: "widgets", key: "left",
                                      value: .stringArray(["workspaces"]))
        #expect(result.contains("left = [\"workspaces\"]"))
    }
}
