import SwiftUI
import Monitors
import NanoBarPluginAPI

// MARK: - ValueField

/// A labeled numeric field combining a fixed-width TextField with a Stepper.
/// Changes commit on focus-loss (TextField) or stepper tap.
struct ValueField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    @State private var textInput: String = ""

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField("", text: $textInput)
                    .frame(width: 56)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commitText() }
                    .onChange(of: value) { _, newVal in
                        textInput = formatValue(newVal)
                    }
                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .onAppear {
            textInput = formatValue(value)
        }
    }

    private func commitText() {
        guard let parsed = Double(textInput) else {
            textInput = formatValue(value)
            return
        }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        value = clamped
        textInput = formatValue(clamped)
    }

    private func formatValue(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
    }
}

// MARK: - SideInsetsEditor

/// Edits a `SideInsets` value with an "Equal on all sides" toggle.
/// When equal: single ValueField; when not equal: four ValueFields (top/right/bottom/left).
///
/// Pass `defaultInsets` to enable write-skip-default: if the written value equals the default
/// the key is removed from config rather than written.
struct SideInsetsEditor: View {
    let label: String
    let section: String
    let key: String
    let current: SideInsets
    var defaultInsets: SideInsets? = nil

    @State private var allEqual: Bool = true
    @State private var top:    Double = 0
    @State private var right:  Double = 0
    @State private var bottom: Double = 0
    @State private var left:   Double = 0

    var body: some View {
        Section(label) {
            Toggle("Equal on all sides", isOn: $allEqual)
                .onChange(of: allEqual) { _, equal in
                    if equal {
                        // Normalize to top value
                        top = top; right = top; bottom = top; left = top
                        writeScalar(top)
                    } else {
                        writeTable(top: top, right: right, bottom: bottom, left: left)
                    }
                }

            if allEqual {
                ValueField(label: "All sides", value: $top, range: 0...60, step: 1)
                    .onChange(of: top) { _, v in writeScalar(v) }
            } else {
                ValueField(label: "Top",    value: $top,    range: 0...60, step: 1)
                    .onChange(of: top)    { _, _ in writeTableCurrent() }
                ValueField(label: "Right",  value: $right,  range: 0...60, step: 1)
                    .onChange(of: right)  { _, _ in writeTableCurrent() }
                ValueField(label: "Bottom", value: $bottom, range: 0...60, step: 1)
                    .onChange(of: bottom) { _, _ in writeTableCurrent() }
                ValueField(label: "Left",   value: $left,   range: 0...60, step: 1)
                    .onChange(of: left)   { _, _ in writeTableCurrent() }
            }
        }
        .onAppear { syncFromCurrent() }
        .onChange(of: current) { _, c in syncFromCurrent(c) }
    }

    private func syncFromCurrent(_ c: SideInsets? = nil) {
        let s = c ?? current
        top    = s.top;  right  = s.right
        bottom = s.bottom;  left = s.left
        allEqual = (top == right && right == bottom && bottom == left)
    }

    private func writeScalar(_ v: Double) {
        if let def = defaultInsets, SideInsets(all: v) == def {
            ConfigLoader.shared.removeKey(section: section, key: key)
        } else {
            ConfigLoader.shared.write(section: section, key: key, value: .integer(Int(v)))
        }
    }

    private func writeTableCurrent() {
        writeTable(top: top, right: right, bottom: bottom, left: left)
    }

    private func writeTable(top: Double, right: Double, bottom: Double, left: Double) {
        if let def = defaultInsets,
           top == def.top && right == def.right && bottom == def.bottom && left == def.left {
            ConfigLoader.shared.removeKey(section: section, key: key)
            return
        }
        let t = Int(top), r = Int(right), b = Int(bottom), l = Int(left)
        let raw = "{ top = \(t), right = \(r), bottom = \(b), left = \(l) }"
        ConfigLoader.shared.write(section: section, key: key, value: .rawLiteral(raw))
    }
}

// MARK: - BorderEditor

/// Edits a `BorderConfig` with enable toggle, adaptive toggle, width ValueField, and ColorPicker.
///
/// Pass `defaultBorder` to enable write-skip-default: if the written value equals the default
/// the key is removed from config rather than written.
struct BorderEditor: View {
    let section: String
    let key: String
    let current: BorderConfig
    var defaultBorder: BorderConfig? = nil

    @State private var enabled:  Bool   = false
    @State private var adaptive: Bool   = true
    @State private var width:    Double = 0.75
    @State private var colorHex: String = BorderConfig.defaultColor

    var body: some View {
        Section("Border") {
            Toggle("Enabled", isOn: $enabled)
                .onChange(of: enabled) { _, isOn in
                    if isOn {
                        if adaptive {
                            writeBool(true)
                        } else {
                            writeCustom()
                        }
                    } else {
                        writeBool(false)
                    }
                }

            if enabled {
                Toggle("Adaptive (auto color)", isOn: $adaptive)
                    .onChange(of: adaptive) { _, isAdaptive in
                        if isAdaptive { writeBool(true) } else { writeCustom() }
                    }

                if !adaptive {
                    ValueField(label: "Width", value: $width, range: 0.25...4, step: 0.25)
                        .onChange(of: width) { _, _ in writeCustom() }

                    LabeledContent("Color") {
                        ColorPicker("", selection: colorBinding, supportsOpacity: true)
                            .labelsHidden()
                    }
                }
            }
        }
        .onAppear { syncFromCurrent() }
        .onChange(of: current) { _, c in syncFromCurrent(c) }
    }

    private func syncFromCurrent(_ override: BorderConfig? = nil) {
        switch override ?? current {
        case .disabled:
            enabled = false; adaptive = true
        case .auto:
            enabled = true; adaptive = true
        case .custom(let w, let c):
            enabled = true; adaptive = false; width = w; colorHex = c
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Theme.color(hex: colorHex) ?? .white },
            set: { color in
                colorHex = color.toHex8() ?? BorderConfig.defaultColor
                writeCustom()
            }
        )
    }

    private func writeBool(_ b: Bool) {
        let value: BorderConfig = b ? .auto : .disabled
        if let def = defaultBorder, value == def {
            ConfigLoader.shared.removeKey(section: section, key: key)
        } else {
            ConfigLoader.shared.write(section: section, key: key, value: .bool(b))
        }
    }

    private func writeCustom() {
        let value = BorderConfig.custom(width: width, color: colorHex)
        if let def = defaultBorder, value == def {
            ConfigLoader.shared.removeKey(section: section, key: key)
        } else {
            let raw = "{ width = \(width), color = \"\(colorHex)\" }"
            ConfigLoader.shared.write(section: section, key: key, value: .rawLiteral(raw))
        }
    }
}

// MARK: - SettingsFieldRow

/// Schema-driven row for a single plugin field.
/// Uses `localValue` as the immediate source of truth so the UI responds
/// instantly to user input. The debounced write to config happens in the
/// background; `localValue` is re-synced when the config reload completes.
struct SettingsFieldRow: View {
    let field: SettingsField
    let pluginID: String
    @ObservedObject private var loader = ConfigLoader.shared

    /// The currently displayed value (string form). Updated immediately on
    /// user interaction; synced back from config after each reload.
    @State private var localValue: String = ""
    /// True while the user is actively editing a text field.
    /// Prevents config reloads from clobbering mid-typing keystrokes.
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent(field.label) {
            fieldControl
        }
        .onAppear { localValue = configValue }
        // Only sync from config when the user is not actively typing.
        .onChange(of: configValue) { _, v in if !isFocused { localValue = v } }
    }

    /// Current persisted value (or schema default if not yet written).
    private var configValue: String {
        loader.config.plugins[pluginID]?.settings[field.key] ?? field.defaultValue
    }

    /// Update local state immediately and schedule the debounced disk write.
    /// If the new value matches the schema default, remove the key instead of writing it,
    /// keeping the config file free of redundant default entries.
    private func commit(_ str: String) {
        localValue = str
        if str == field.defaultValue {
            ConfigLoader.shared.removeKey(section: "plugins.\(pluginID)", key: field.key)
        } else {
            ConfigLoader.shared.write(section: "plugins.\(pluginID)", key: field.key, value: .string(str))
        }
    }

    // MARK: - Control

    @ViewBuilder private var fieldControl: some View {
        switch field.type {
        case .text:
            TextField("", text: Binding(get: { localValue }, set: { commit($0) }))
                .frame(maxWidth: 200)
                .focused($isFocused)

        case .color:
            ColorPicker("", selection: Binding(
                get: {
                    if !localValue.isEmpty, let c = Theme.color(hex: localValue) { return c }
                    return field.adaptiveColor ?? .white
                },
                set: { color in
                    if let hex = color.toHex8() { commit(hex) }
                }
            ), supportsOpacity: true)
            .labelsHidden()

        case .toggle:
            Toggle("", isOn: Binding(
                get: { localValue == "true" },
                set: { commit($0 ? "true" : "false") }
            )).labelsHidden()

        case .picker(let options):
            Picker("", selection: Binding(get: { localValue }, set: { commit($0) })) {
                ForEach(options, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 200)

        case .stepper(let min, let max, let step):
            let dbl = Binding<Double>(
                get: { Double(localValue) ?? Double(field.defaultValue) ?? min },
                set: { v in
                    let c = Swift.min(Swift.max(v, min), max)
                    commit(step >= 1 && c.truncatingRemainder(dividingBy: 1) == 0
                           ? String(Int(c)) : String(c))
                }
            )
            HStack(spacing: 4) {
                TextField("", text: Binding(
                    get: {
                        let v = dbl.wrappedValue
                        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
                    },
                    set: { text in
                        if let p = Double(text) {
                            dbl.wrappedValue = Swift.min(Swift.max(p, min), max)
                        }
                    }
                ))
                .focused($isFocused)
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
                Stepper("", value: dbl, in: min...max, step: step)
                    .labelsHidden()
            }
        }
    }
}
