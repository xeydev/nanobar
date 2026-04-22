import SwiftUI
import Monitors
import Widgets
import NanoBarPluginAPI

// MARK: - PluginDetailView

struct PluginDetailView: View {
    let schema: PluginSchema

    @ObservedObject private var loader = ConfigLoader.shared
    @State private var pillOverrideEnabled: Bool = false

    private var pluginSection: String { "plugins.\(schema.pluginID)" }
    private var pillSection:   String { "plugins.\(schema.pluginID).pill" }

    /// Pill config to show: the override if it exists, else fall back to global defaults.
    private var overrideOrGlobal: NanoConfig.PillConfig {
        loader.config.plugins[schema.pluginID]?.pill ?? loader.config.pill
    }

    var body: some View {
        Form {
            if !schema.fields.isEmpty {
                pluginFieldsSection
            }
            pillOverrideSection
            resetSection
        }
        .formStyle(.grouped)
        .navigationTitle(schema.displayName)
        .onAppear {
            pillOverrideEnabled = loader.config.plugins[schema.pluginID]?.pill != nil
        }
        .onReceive(loader.$config) { cfg in
            // Sync pill toggle when config reloads (e.g. external edit removes the section).
            pillOverrideEnabled = cfg.plugins[schema.pluginID]?.pill != nil
        }
    }

    // MARK: - Plugin settings fields

    private var pluginFieldsSection: some View {
        Section(schema.displayName) {
            ForEach(schema.fields, id: \.key) { field in
                SettingsFieldRow(field: field, pluginID: schema.pluginID)
            }
        }
    }

    // MARK: - Pill override

    private var pillOverrideSection: some View {
        Section("Pill Override") {
            Toggle("Override pill style", isOn: $pillOverrideEnabled)
                .onChange(of: pillOverrideEnabled) { _, enabled in
                    if enabled {
                        // Create the section by writing the current global style as default.
                        ConfigLoader.shared.write(
                            section: pillSection,
                            key: "style",
                            value: .string(loader.config.pill.style)
                        )
                    } else {
                        ConfigLoader.shared.removeSection(pillSection)
                    }
                }

            if pillOverrideEnabled {
                PillConfigEditor(section: pillSection, current: overrideOrGlobal)
            }
        }
    }

    // MARK: - Reset buttons

    private var resetSection: some View {
        Section {
            Button("Reset settings", role: .destructive) {
                // Remove child subsections before the parent so no orphaned sections remain.
                ConfigLoader.shared.removeSection(pillSection)
                ConfigLoader.shared.removeSection(pluginSection)
                pillOverrideEnabled = false
            }
            if pillOverrideEnabled {
                Button("Reset pill override", role: .destructive) {
                    ConfigLoader.shared.removeSection(pillSection)
                    pillOverrideEnabled = false
                }
            }
        }
    }
}
