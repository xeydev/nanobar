import Testing
import NanoBarPluginAPI

@Suite("SettingsSchema.resolvedSettings")
struct SettingsSchemaTests {

    private struct MockPlugin: NanoBarPluginSettingsProvider {
        var displayName: String { "Mock" }
        func settingsSchema() -> [SettingsField] {[
            SettingsField(key: "format", label: "Format", type: .text,  defaultValue: "HH:mm"),
            SettingsField(key: "color",  label: "Color",  type: .color, defaultValue: "#FF0000FF"),
        ]}
    }

    @Test("empty raw dict → all schema defaults returned")
    func emptyRawReturnsAllDefaults() {
        let result = MockPlugin().resolvedSettings([:])
        #expect(result["format"] == "HH:mm")
        #expect(result["color"] == "#FF0000FF")
        #expect(result.count == 2)
    }

    @Test("partial raw dict → missing keys filled from schema defaults")
    func partialRawFillsMissingKeys() {
        let result = MockPlugin().resolvedSettings(["format": "EEE dd"])
        #expect(result["format"] == "EEE dd")      // preserved
        #expect(result["color"] == "#FF0000FF")    // filled from schema
    }

    @Test("full raw dict → schema defaults not applied")
    func fullRawNotOverridden() {
        let result = MockPlugin().resolvedSettings(["format": "custom", "color": "#00FF00FF"])
        #expect(result["format"] == "custom")
        #expect(result["color"] == "#00FF00FF")
    }

    @Test("extra keys not in schema are preserved as-is")
    func extraKeysPreserved() {
        let result = MockPlugin().resolvedSettings(["unknown": "value", "format": "custom"])
        #expect(result["unknown"] == "value")
        #expect(result["format"] == "custom")
        #expect(result["color"] == "#FF0000FF")  // from schema
    }

    @Test("raw value equal to default is not replaced (key is present)")
    func sameAsDefaultKeyIsKept() {
        let result = MockPlugin().resolvedSettings(["format": "HH:mm"])
        #expect(result["format"] == "HH:mm")
        #expect(result["color"] == "#FF0000FF")
    }
}
