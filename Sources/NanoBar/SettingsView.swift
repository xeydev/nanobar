import SwiftUI
import Monitors
import Widgets
import NanoBarPluginAPI

// MARK: - Navigation items

enum NavItem: Hashable {
    case widgets
    case bar
    case pill
    case plugin(String)
}

// MARK: - Root SettingsView

struct SettingsView: View {
    @State private var selection: NavItem? = .widgets
    private let schemas = PluginLoader.shared.pluginSchemas

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, schemas: schemas)
                .navigationSplitViewColumnWidth(min: 140, ideal: 170, max: 200)
        } detail: {
            detailView
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 420, idealHeight: 540)
    }

    @ViewBuilder private var detailView: some View {
        switch selection {
        case .widgets:
            WidgetsDetailView()
        case .bar:
            BarDetailView()
        case .pill:
            PillDetailView()
        case .plugin(let id):
            if let schema = schemas.first(where: { $0.pluginID == id }) {
                PluginDetailView(schema: schema)
            } else {
                ContentUnavailableView("Plugin not found", systemImage: "puzzlepiece.extension.fill")
            }
        case nil:
            ContentUnavailableView("Select a section", systemImage: "sidebar.left")
        }
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @Binding var selection: NavItem?
    let schemas: [PluginSchema]

    var body: some View {
        List(selection: $selection) {
            Section("Layout") {
                Label("Widgets", systemImage: "rectangle.3.group")
                    .tag(NavItem.widgets)
            }
            Section("Appearance") {
                Label("Bar", systemImage: "menubar.rectangle")
                    .tag(NavItem.bar)
                Label("Pill", systemImage: "capsule")
                    .tag(NavItem.pill)
            }

            if !schemas.isEmpty {
                Section("Plugins") {
                    ForEach(schemas, id: \.pluginID) { schema in
                        Label(schema.displayName, systemImage: "puzzlepiece.extension")
                            .tag(NavItem.plugin(schema.pluginID))
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Pill detail view (global)

private struct PillDetailView: View {
    @ObservedObject private var loader = ConfigLoader.shared

    var body: some View {
        Form {
            PillConfigEditor(section: "pill", current: loader.config.pill)
            Section {
                Button("Reset to defaults", role: .destructive) {
                    ConfigLoader.shared.removeSection("pill")
                    ConfigLoader.shared.removeSection("pill.liquidGlass")
                    ConfigLoader.shared.removeSection("pill.liquidGlass.blur")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pill")
    }
}
