import SwiftUI
import Monitors
import NanoBarPluginAPI

// MARK: - PillConfigEditor

/// Full pill configuration editor. Reusable for both the global Pill pane
/// and per-plugin pill override sections.
///
/// `section`  — the TOML section path to write into (e.g. `"pill"` or `"plugins.clock.pill"`).
/// `current`  — the pill config to display (may be the global default when used as an override).
struct PillConfigEditor: View {
    let section: String
    let current: NanoConfig.PillConfig

    @ObservedObject private var loader = ConfigLoader.shared

    // Local state — updated immediately on user interaction; synced back when config reloads.
    @State private var localStyle:        String = "liquidGlass"
    @State private var localHeight:       Double = 30
    @State private var localCornerRadius: Double = 15

    // LiquidGlass
    @State private var defaultEffect: String = "clear"
    @State private var defaultTint:   String = ""
    @State private var hoverEffect:   String = "regular"
    @State private var hoverTint:     String = "#FFFFFF30"
    @State private var toggledEffect: String = "regular"
    @State private var toggledTint:   String = "#FFFFFF30"

    // Blur fallback
    @State private var blurMaterial: String = "regular"
    @State private var blurSpecular: Bool   = true
    @State private var blurShadow:   Bool   = true

    private var live: NanoConfig.PillConfig { liveConfig() ?? current }
    private var glassSection: String { "\(section).liquidGlass" }
    private var blurPath:     String { "\(section).liquidGlass.blur" }

    var body: some View {
        Group {
            Section("Style") {
                Picker("Style", selection: $localStyle) {
                    Text("Liquid Glass").tag("liquidGlass")
                    Text("Solid").tag("solid")
                    Text("None").tag("none")
                }
                .onChange(of: localStyle) { _, v in write("style", .string(v)) }
            }

            Section("Dimensions") {
                ValueField(label: "Height",       value: $localHeight,       range: 16...60, step: 1)
                    .onChange(of: localHeight)       { _, v in write("height",       .double(v)) }
                ValueField(label: "Corner radius", value: $localCornerRadius, range: 0...30,  step: 1)
                    .onChange(of: localCornerRadius) { _, v in write("cornerRadius", .double(v)) }
            }

            BorderEditor(section: section, key: "border", current: live.border)

            if localStyle == "liquidGlass" {
                Section("Liquid Glass") {
                    glassRow(label: "Default effect",
                             effect: $defaultEffect, effectKey: "defaultEffect",
                             tint:   $defaultTint,   tintKey:   "defaultTint")
                    glassRow(label: "Hover effect",
                             effect: $hoverEffect,   effectKey: "hoverEffect",
                             tint:   $hoverTint,     tintKey:   "hoverTint")
                    glassRow(label: "Toggled effect",
                             effect: $toggledEffect, effectKey: "toggledEffect",
                             tint:   $toggledTint,   tintKey:   "toggledTint")
                }

                Section("Blur Fallback (pre-macOS 26)") {
                    Picker("Material", selection: $blurMaterial) {
                        Text("Regular").tag("regular")
                        Text("Thin").tag("thin")
                        Text("Ultra Thin").tag("ultraThin")
                    }
                    .onChange(of: blurMaterial) { _, v in
                        ConfigLoader.shared.write(section: blurPath, key: "material", value: .string(v))
                    }
                    Toggle("Specular highlight", isOn: $blurSpecular)
                        .onChange(of: blurSpecular) { _, v in
                            ConfigLoader.shared.write(section: blurPath, key: "specular", value: .bool(v))
                        }
                    Toggle("Drop shadow", isOn: $blurShadow)
                        .onChange(of: blurShadow) { _, v in
                            ConfigLoader.shared.write(section: blurPath, key: "shadow", value: .bool(v))
                        }
                }
            }
        }
        .onAppear { sync(live) }
        .onChange(of: live) { _, p in sync(p) }
    }

    // MARK: - Glass row helper

    @ViewBuilder
    private func glassRow(label: String,
                           effect: Binding<String>, effectKey: String,
                           tint:   Binding<String>, tintKey:   String) -> some View {
        LabeledContent(label) {
            HStack {
                Picker("", selection: effect) {
                    Text("Regular").tag("regular")
                    Text("Clear").tag("clear")
                    Text("Identity").tag("identity")
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: effect.wrappedValue) { _, v in
                    ConfigLoader.shared.write(section: glassSection, key: effectKey, value: .string(v))
                }

                ColorPicker("", selection: Binding(
                    get: { Theme.color(hex: tint.wrappedValue) ?? Color.white.opacity(0) },
                    set: { color in
                        let hex = color.toHex8() ?? "#FFFFFF00"
                        tint.wrappedValue = hex
                        ConfigLoader.shared.write(section: glassSection, key: tintKey, value: .string(hex))
                    }
                ), supportsOpacity: true)
                .labelsHidden()
                .frame(width: 40)
            }
        }
    }

    // MARK: - Helpers

    private func write(_ key: String, _ value: TOMLValue) {
        ConfigLoader.shared.write(section: section, key: key, value: value)
    }

    /// Populate local state from a PillConfig (on appear and on external reload).
    private func sync(_ p: NanoConfig.PillConfig) {
        localStyle        = p.style
        localHeight       = p.height
        localCornerRadius = p.cornerRadius
        let g = p.liquidGlass
        defaultEffect = g.defaultEffect;  defaultTint   = g.defaultTint   ?? ""
        hoverEffect   = g.hoverEffect;    hoverTint     = g.hoverTint     ?? ""
        toggledEffect = g.toggledEffect;  toggledTint   = g.toggledTint   ?? ""
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
