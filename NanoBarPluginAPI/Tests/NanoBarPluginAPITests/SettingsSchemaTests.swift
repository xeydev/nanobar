import Foundation
import Testing
@testable import NanoBarPluginAPI

@Suite("SettingsField")
struct SettingsFieldTests {

    @Test("text field stores key, label, default")
    func textField() {
        let f = SettingsField(key: "format", label: "Format", type: .text, defaultValue: "HH:mm")
        #expect(f.key == "format")
        #expect(f.label == "Format")
        #expect(f.defaultValue == "HH:mm")
        guard case .text = f.type else { Issue.record("Expected .text"); return }
    }

    @Test("color field stores type")
    func colorField() {
        let f = SettingsField(key: "color", label: "Color", type: .color, defaultValue: "#FFFFFF")
        guard case .color = f.type else { Issue.record("Expected .color"); return }
    }

    @Test("toggle field stores type")
    func toggleField() {
        let f = SettingsField(key: "enabled", label: "Enabled", type: .toggle, defaultValue: "true")
        guard case .toggle = f.type else { Issue.record("Expected .toggle"); return }
    }

    @Test("picker field stores options")
    func pickerField() {
        let opts = [PickerOption(value: "a", label: "Option A"), PickerOption(value: "b", label: "Option B")]
        let f = SettingsField(key: "mode", label: "Mode", type: .picker(options: opts), defaultValue: "a")
        guard case .picker(let stored) = f.type else { Issue.record("Expected .picker"); return }
        #expect(stored.count == 2)
        #expect(stored[0].value == "a")
        #expect(stored[0].label == "Option A")
        #expect(stored[1].value == "b")
    }

    @Test("stepper field stores min, max, step")
    func stepperField() {
        let f = SettingsField(key: "work", label: "Work (min)", type: .stepper(min: 1, max: 60, step: 1), defaultValue: "25")
        guard case .stepper(let min, let max, let step) = f.type else { Issue.record("Expected .stepper"); return }
        #expect(min == 1)
        #expect(max == 60)
        #expect(step == 1)
    }
}

@Suite("PickerOption")
struct PickerOptionTests {

    @Test("stores value and label")
    func stores() {
        let o = PickerOption(value: "solid", label: "Solid")
        #expect(o.value == "solid")
        #expect(o.label == "Solid")
    }
}

// File-scope stubs (Swift 6: NSObject subclasses cannot be declared inside function bodies)
private final class StubPlugin: NSObject, NanoBarPluginEntry, NanoBarPluginSettingsProvider {
    var pluginID: String { "stub" }
    @MainActor func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String : String]) {}
    var displayName: String { "Stub Widget" }
    func settingsSchema() -> [SettingsField] {
        [SettingsField(key: "color", label: "Color", type: .color, defaultValue: "#FFFFFF")]
    }
}

private final class MinimalPlugin: NSObject, NanoBarPluginEntry {
    var pluginID: String { "minimal" }
    @MainActor func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String : String]) {}
}

@Suite("NanoBarPluginSettingsProvider")
struct NanoBarPluginSettingsProviderTests {

    @Test("cast succeeds for conforming class")
    func castSucceeds() {
        let plugin: any NanoBarPluginEntry = StubPlugin()
        let provider = plugin as? any NanoBarPluginSettingsProvider
        #expect(provider != nil)
        #expect(provider?.displayName == "Stub Widget")
        #expect(provider?.settingsSchema().count == 1)
    }

    @Test("cast fails for non-conforming class")
    func castFails() {
        let plugin: any NanoBarPluginEntry = MinimalPlugin()
        #expect((plugin as? any NanoBarPluginSettingsProvider) == nil)
    }
}
