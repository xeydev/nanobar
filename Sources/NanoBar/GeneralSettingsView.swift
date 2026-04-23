import SwiftUI
import Monitors

// MARK: - GeneralDetailView

struct GeneralDetailView: View {
    @ObservedObject private var loader = ConfigLoader.shared

    private var selectedTheme: AppTheme { loader.config.resolvedTheme }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { selectedTheme },
                    set: { write($0) }
                )) {
                    Text("System").tag(AppTheme.system)
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private func write(_ theme: AppTheme) {
        if theme == .system {
            ConfigLoader.shared.removeKey(section: "app", key: "theme")
        } else {
            ConfigLoader.shared.write(section: "app", key: "theme", value: .string(theme.rawValue))
        }
    }
}
