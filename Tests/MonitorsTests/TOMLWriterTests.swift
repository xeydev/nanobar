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

    @Test("removeSection does not remove child subsections")
    func removeSectionLeavesChildren() {
        // Documents the invariant that removeSection is single-level only.
        // Callers must enumerate all child paths (deepest-first) to avoid
        // leaving orphaned sections that TOMLKit re-infers as non-nil parents.
        let raw = """
            [plugins.clock.pill]
            style = "solid"

            [plugins.clock.pill.liquidGlass]
            defaultEffect = "regular"

            [plugins.clock.pill.liquidGlass.blur]
            material = "thin"
            """
        let result = TOMLWriter.removeSection(raw: raw, section: "plugins.clock.pill")
        #expect(!result.contains("style = \"solid\""))
        #expect(result.contains("[plugins.clock.pill.liquidGlass]"))
        #expect(result.contains("defaultEffect = \"regular\""))
        #expect(result.contains("[plugins.clock.pill.liquidGlass.blur]"))
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

    // MARK: - Hierarchical insertion order

    @Test("new section inserted before alphabetically later sibling")
    func insertionBeforeLaterSibling() {
        let raw = "[plugins.clock]\nformat = \"%H:%M\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.battery", key: "color", value: .string("#00FF00"))
        let batteryRange = result.range(of: "[plugins.battery]")!
        let clockRange   = result.range(of: "[plugins.clock]")!
        #expect(batteryRange.lowerBound < clockRange.lowerBound)
    }

    @Test("child section inserted after parent, before parent's sibling")
    func insertionChildAfterParent() {
        let raw = "[plugins.clock]\nformat = \"%H:%M\"\n\n[plugins.volume]\nicon = \"speaker\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock.pill", key: "style", value: .string("solid"))
        let clockRange  = result.range(of: "[plugins.clock]")!
        let pillRange   = result.range(of: "[plugins.clock.pill]")!
        let volumeRange = result.range(of: "[plugins.volume]")!
        #expect(clockRange.lowerBound < pillRange.lowerBound)
        #expect(pillRange.lowerBound < volumeRange.lowerBound)
    }

    @Test("new top-level section inserted in sorted position between existing sections")
    func insertionTopLevelSorted() {
        let raw = "[bar]\nheight = 30\n\n[plugins.clock]\nformat = \"%H:%M\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "pill", key: "style", value: .string("liquidGlass"))
        let barRange     = result.range(of: "[bar]")!
        let pillRange    = result.range(of: "[pill]")!
        let pluginsRange = result.range(of: "[plugins.clock]")!
        #expect(barRange.lowerBound < pillRange.lowerBound)
        #expect(pillRange.lowerBound < pluginsRange.lowerBound)
    }

    @Test("new section appended when alphabetically last")
    func insertionAppendWhenLast() {
        let raw = "[bar]\nheight = 30\n\n[pill]\nstyle = \"liquidGlass\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "plugins.clock", key: "format", value: .string("%H:%M"))
        let pillRange    = result.range(of: "[pill]")!
        let pluginsRange = result.range(of: "[plugins.clock]")!
        #expect(pillRange.lowerBound < pluginsRange.lowerBound)
    }

    @Test("new section inserted at start when alphabetically first")
    func insertionAtStartWhenFirst() {
        let raw = "[plugins.clock]\nformat = \"%H:%M\"\n"
        let result = TOMLWriter.patch(raw: raw, section: "bar", key: "height", value: .integer(30))
        let barRange     = result.range(of: "[bar]")!
        let pluginsRange = result.range(of: "[plugins.clock]")!
        #expect(barRange.lowerBound < pluginsRange.lowerBound)
    }

    // MARK: - removeKey

    @Test("removes key leaving other keys and section header intact")
    func removeKeyMultipleKeys() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\ncolor = \"#FF0000\"\n"
        let result = TOMLWriter.removeKey(raw: raw, section: "plugins.clock", key: "format")
        #expect(!result.contains("format"))
        #expect(result.contains("color = \"#FF0000\""))
        #expect(result.contains("[plugins.clock]"))
    }

    @Test("removes section header when last key is removed and section is empty")
    func removeKeyLastKeyRemovesSection() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n\n[plugins.volume]\ncolor = \"#FF0000\"\n"
        let result = TOMLWriter.removeKey(raw: raw, section: "plugins.clock", key: "format")
        #expect(!result.contains("[plugins.clock]"))
        #expect(!result.contains("format"))
        #expect(result.contains("[plugins.volume]"))
        #expect(result.contains("color = \"#FF0000\""))
    }

    @Test("no-op when key not found in section")
    func removeKeyNotFoundNoOp() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.removeKey(raw: raw, section: "plugins.clock", key: "color")
        #expect(result == raw)
    }

    @Test("no-op when section not found")
    func removeKeySectionNotFoundNoOp() {
        let raw = "[plugins.clock]\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.removeKey(raw: raw, section: "plugins.volume", key: "color")
        #expect(result == raw)
    }

    @Test("preserves comments and keeps section header when comments remain after key removal")
    func removeKeyPreservesCommentsKeepsHeader() {
        let raw = "[plugins.clock]\n# date format\nformat = \"HH:mm\"\n"
        let result = TOMLWriter.removeKey(raw: raw, section: "plugins.clock", key: "format")
        #expect(!result.contains("format = \"HH:mm\""))
        #expect(result.contains("[plugins.clock]"))
        #expect(result.contains("# date format"))
    }

    @Test("removes only the target key, preserving other keys in section")
    func removeKeyOnlyRemovesTargetKey() {
        let raw = "[bar]\nminHeight = 30\ncornerRadius = 0\nshadow = false\n"
        let result = TOMLWriter.removeKey(raw: raw, section: "bar", key: "shadow")
        #expect(!result.contains("shadow"))
        #expect(result.contains("minHeight = 30"))
        #expect(result.contains("cornerRadius = 0"))
        #expect(result.contains("[bar]"))
    }

    @Test("no double blank lines after empty section removal")
    func removeKeyNoDoubleBlankLines() {
        let raw = "[bar]\nheight = 30\n\n[pill]\nstyle = \"glass\"\n"
        let result = TOMLWriter.removeKey(raw: raw, section: "bar", key: "height")
        #expect(!result.contains("\n\n\n"))
        #expect(result.contains("[pill]"))
        #expect(result.contains("style = \"glass\""))
    }

    @Test("removes only the matching key, not keys that share a prefix")
    func removeKeyNoPrefixCollision() {
        let raw = "[plugins.battery]\ncolor = \"#00FF00\"\nwarnColor = \"#FFAA00\"\n"
        let result = TOMLWriter.removeKey(raw: raw, section: "plugins.battery", key: "color")
        #expect(!result.contains("color = \"#00FF00\""))
        #expect(result.contains("warnColor = \"#FFAA00\""))
    }
}
