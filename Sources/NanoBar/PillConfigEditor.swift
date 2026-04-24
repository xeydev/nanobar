import SwiftUI
import Monitors
import NanoBarPluginAPI

// MARK: - PillConfigEditor

/// Full pill configuration editor. Reusable for both the global Pill pane
/// and per-plugin pill override sections.
///
/// `section`  — the TOML section path to write into (e.g. `"pill"` or `"plugins.clock.pill"`).
/// `current`  — the pill config to display (may be the global default when used as an override).
/// `defaults` — when non-nil, keys whose value matches the corresponding default are removed
///              from config instead of written (write-skip-default). Pass nil for per-plugin
///              overrides where every change should always be persisted.
struct PillConfigEditor: View {
    let section: String
    let current: NanoConfig.PillConfig
    var defaults: NanoConfig.PillConfig? = nil

    @ObservedObject private var loader = ConfigLoader.shared

    // Local state — updated immediately on user interaction; synced back when config reloads.
    @State private var localStyle:        String = "liquidGlass"
    @State private var localHeight:       Double = 30
    @State private var localCornerRadius: Double = 15

    // LiquidGlass
    @State private var defaultEffect: String = "clear"
    @State private var hoverEffect:   String = "regular"
    @State private var toggledEffect: String = "regular"

    // Solid
    @State private var solidColor:  String = "#1C1C1ECC"
    @State private var solidShadow: Bool   = false

    // Blur style
    @State private var blurStyleMaterial: String = "regular"
    @State private var blurStyleSpecular: Bool   = true
    @State private var blurStyleShadow:   Bool   = false

    // LiquidGlass blur fallback
    @State private var blurMaterial: String = "regular"
    @State private var blurSpecular: Bool   = true
    @State private var blurShadow:   Bool   = true

    private var live: NanoConfig.PillConfig { liveConfig() ?? current }
    private var glassSection: String { "\(section).liquidGlass" }
    private var blurPath:     String { "\(section).liquidGlass.blur" }
    private var blurStylePath: String { "\(section).blur" }

    var body: some View {
        Group {
            Section("Style") {
                Picker("Style", selection: $localStyle) {
                    Text("Liquid Glass").tag("liquidGlass")
                    Text("Blur").tag("blur")
                    Text("Solid").tag("solid")
                    Text("None").tag("none")
                }
                .onChange(of: localStyle) { _, v in write("style", .string(v), isDefault: v == defaults?.style) }
            }

            Section("Dimensions") {
                ValueField(label: "Height",       value: $localHeight,       range: 16...60, step: 1)
                    .onChange(of: localHeight)       { _, v in write("height",       .double(v), isDefault: v == defaults?.height) }
                ValueField(label: "Corner radius", value: $localCornerRadius, range: 0...30,  step: 1)
                    .onChange(of: localCornerRadius) { _, v in write("cornerRadius", .double(v), isDefault: v == defaults?.cornerRadius) }
            }

            BorderEditor(section: section, key: "border", current: live.border,
                         defaultBorder: defaults?.border)

            if localStyle == "solid" {
                Section("Solid") {
                    LabeledContent("Color") {
                        ColorPicker("", selection: solidColorBinding, supportsOpacity: true)
                            .labelsHidden()
                    }
                    Toggle("Drop shadow", isOn: $solidShadow)
                        .onChange(of: solidShadow) { _, v in
                            write("solidShadow", .bool(v), isDefault: v == defaults?.solidShadow)
                        }
                }
            }

            if localStyle == "blur" {
                Section("Blur") {
                    Picker("Material", selection: $blurStyleMaterial) {
                        Text("Regular").tag("regular")
                        Text("Thin").tag("thin")
                        Text("Ultra Thin").tag("ultraThin")
                    }
                    .onChange(of: blurStyleMaterial) { _, v in
                        writeSection(blurStylePath, key: "material", value: .string(v),
                                     isDefault: v == defaults?.blur.material)
                    }
                    Toggle("Specular highlight", isOn: $blurStyleSpecular)
                        .onChange(of: blurStyleSpecular) { _, v in
                            writeSection(blurStylePath, key: "specular", value: .bool(v),
                                         isDefault: v == defaults?.blur.specular)
                        }
                    Toggle("Drop shadow", isOn: $blurStyleShadow)
                        .onChange(of: blurStyleShadow) { _, v in
                            writeSection(blurStylePath, key: "shadow", value: .bool(v),
                                         isDefault: v == defaults?.blur.shadow)
                        }
                }
            }

            if localStyle == "liquidGlass" {
                Section("Liquid Glass") {
                    glassRow(label: "Default effect", effect: $defaultEffect, effectKey: "defaultEffect", defaultEffect: defaults?.liquidGlass.defaultEffect)
                    glassRow(label: "Hover effect",   effect: $hoverEffect,   effectKey: "hoverEffect",   defaultEffect: defaults?.liquidGlass.hoverEffect)
                    glassRow(label: "Toggled effect", effect: $toggledEffect, effectKey: "toggledEffect", defaultEffect: defaults?.liquidGlass.toggledEffect)
                }

                Section("Blur Fallback (pre-macOS 26)") {
                    Picker("Material", selection: $blurMaterial) {
                        Text("Regular").tag("regular")
                        Text("Thin").tag("thin")
                        Text("Ultra Thin").tag("ultraThin")
                    }
                    .onChange(of: blurMaterial) { _, v in
                        writeSection(blurPath, key: "material", value: .string(v),
                                     isDefault: v == defaults?.liquidGlass.blur.material)
                    }
                    Toggle("Specular highlight", isOn: $blurSpecular)
                        .onChange(of: blurSpecular) { _, v in
                            writeSection(blurPath, key: "specular", value: .bool(v),
                                         isDefault: v == defaults?.liquidGlass.blur.specular)
                        }
                    Toggle("Drop shadow", isOn: $blurShadow)
                        .onChange(of: blurShadow) { _, v in
                            writeSection(blurPath, key: "shadow", value: .bool(v),
                                         isDefault: v == defaults?.liquidGlass.blur.shadow)
                        }
                }
            }
        }
        .onAppear { sync(live) }
        .onChange(of: live) { _, p in sync(p) }
    }

    // MARK: - Solid color binding

    private var solidColorBinding: Binding<Color> {
        Binding(
            get: { Theme.color(hex: solidColor) ?? Color(red: 0.11, green: 0.11, blue: 0.118, opacity: 0.8) },
            set: { color in
                solidColor = color.toHex8() ?? "#1C1C1ECC"
                write("solidColor", .string(solidColor), isDefault: solidColor == defaults?.solidColor)
            }
        )
    }

    // MARK: - Glass row helper

    @ViewBuilder
    private func glassRow(label: String, effect: Binding<String>, effectKey: String, defaultEffect: String?) -> some View {
        Picker(label, selection: effect) {
            Text("Regular").tag("regular")
            Text("Clear").tag("clear")
            Text("Identity").tag("identity")
        }
        .onChange(of: effect.wrappedValue) { _, v in
            writeSection(glassSection, key: effectKey, value: .string(v),
                         isDefault: v == defaultEffect)
        }
    }

    // MARK: - Helpers

    private func write(_ key: String, _ value: TOMLValue, isDefault: Bool = false) {
        if isDefault, defaults != nil {
            ConfigLoader.shared.removeKey(section: section, key: key)
        } else {
            ConfigLoader.shared.write(section: section, key: key, value: value)
        }
    }

    private func writeSection(_ section: String, key: String, value: TOMLValue, isDefault: Bool = false) {
        if isDefault, defaults != nil {
            ConfigLoader.shared.removeKey(section: section, key: key)
        } else {
            ConfigLoader.shared.write(section: section, key: key, value: value)
        }
    }

    /// Populate local state from a PillConfig (on appear and on external reload).
    private func sync(_ p: NanoConfig.PillConfig) {
        localStyle        = p.style
        localHeight       = p.height
        localCornerRadius = p.cornerRadius
        solidColor        = p.solidColor
        solidShadow       = p.solidShadow
        blurStyleMaterial = p.blur.material
        blurStyleSpecular = p.blur.specular
        blurStyleShadow   = p.blur.shadow
        let g = p.liquidGlass
        defaultEffect = g.defaultEffect
        hoverEffect   = g.hoverEffect
        toggledEffect = g.toggledEffect
        let b = g.blur
        blurMaterial = b.material;  blurSpecular = b.specular;  blurShadow = b.shadow
    }

    private func liveConfig() -> NanoConfig.PillConfig? {
        if section == "pill" { return loader.config.pill }
        let parts = section.split(separator: ".").map(String.init)
        guard parts.count == 3, parts[0] == "plugins", parts[2] == "pill" else { return nil }
        return loader.config.plugins[parts[1]]?.pill
    }
}
