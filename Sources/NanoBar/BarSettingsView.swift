import SwiftUI
import Monitors
import NanoBarPluginAPI

// MARK: - BarDetailView

struct BarDetailView: View {
    @ObservedObject private var loader = ConfigLoader.shared

    // Local state — updated immediately on user interaction, synced back on config reload.
    @State private var minHeight:    Double = 30
    @State private var cornerRadius: Double = 0
    @State private var shadow:       Bool   = false
    @State private var bgMode:       String = "none"
    @State private var bgColorHex:   String = "#000000FF"

    var body: some View {
        Form {
            appearanceSection
            SideInsetsEditor(label: "Margin",  section: "bar", key: "margin",  current: loader.config.bar.margin,
                             defaultInsets: NanoConfig.BarConfig().margin)
            SideInsetsEditor(label: "Padding", section: "bar", key: "padding", current: loader.config.bar.padding,
                             defaultInsets: NanoConfig.BarConfig().padding)
            BorderEditor(section: "bar", key: "border", current: loader.config.bar.border,
                         defaultBorder: NanoConfig.BarConfig().border)
            Section {
                Button("Reset to defaults", role: .destructive) {
                    ConfigLoader.shared.removeSection("bar")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Bar")
        .onAppear { syncFromConfig() }
        // Sync each field independently so external reloads (e.g. reset) are reflected.
        .onChange(of: loader.config.bar.minHeight)     { _, v in minHeight = v }
        .onChange(of: loader.config.bar.cornerRadius) { _, v in cornerRadius = v }
        .onChange(of: loader.config.bar.shadow)       { _, v in shadow = v }
        .onChange(of: loader.config.bar.background)   { _, v in parseBg(v) }
    }

    // MARK: - Appearance section

    @ViewBuilder private var appearanceSection: some View {
        Section("Appearance") {
            backgroundRow
            ValueField(label: "Min Height",     value: $minHeight,    range: 20...60, step: 1)
                .onChange(of: minHeight)    { _, v in write("minHeight",    .double(v), isDefault: v == NanoConfig.BarConfig().minHeight) }
            ValueField(label: "Corner radius", value: $cornerRadius, range: 0...30,  step: 1)
                .onChange(of: cornerRadius) { _, v in write("cornerRadius", .double(v), isDefault: v == NanoConfig.BarConfig().cornerRadius) }
            Toggle("Shadow", isOn: $shadow)
                .onChange(of: shadow) { _, v in write("shadow", .bool(v), isDefault: v == NanoConfig.BarConfig().shadow) }
        }
    }

    @ViewBuilder private var backgroundRow: some View {
        Picker("Background", selection: $bgMode) {
            Text("None").tag("none")
            Text("Blur").tag("blur")
            Text("Color").tag("color")
        }
        .onChange(of: bgMode) { _, mode in
            let def = NanoConfig.BarConfig().background
            switch mode {
            case "color": write("background", .string("color:\(bgColorHex)"))
            default:      write("background", .string(mode), isDefault: mode == def)
            }
        }

        if bgMode == "color" {
            LabeledContent("Background color") {
                ColorPicker("", selection: Binding(
                    get: { Theme.color(hex: bgColorHex) ?? .black },
                    set: { color in
                        bgColorHex = color.toHex8() ?? "#000000FF"
                        write("background", .string("color:\(bgColorHex)"))
                    }
                ), supportsOpacity: true)
                .labelsHidden()
            }
        }
    }

    // MARK: - Helpers

    private func write(_ key: String, _ value: TOMLValue, isDefault: Bool = false) {
        if isDefault {
            ConfigLoader.shared.removeKey(section: "bar", key: key)
        } else {
            ConfigLoader.shared.write(section: "bar", key: key, value: value)
        }
    }

    private func syncFromConfig() {
        minHeight    = loader.config.bar.minHeight
        cornerRadius = loader.config.bar.cornerRadius
        shadow       = loader.config.bar.shadow
        parseBg(loader.config.bar.background)
    }

    private func parseBg(_ bg: String) {
        if bg.hasPrefix("color:") {
            bgMode     = "color"
            bgColorHex = String(bg.dropFirst("color:".count))
        } else {
            bgMode = bg
        }
    }
}
