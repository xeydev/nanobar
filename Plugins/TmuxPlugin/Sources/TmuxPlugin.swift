import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - Live state

/// Polls `tmux list-sessions` every 10 seconds and publishes the count.
@MainActor
private final class TmuxState: ObservableObject {
    @Published var sessionCount: Int = 0
    private var pollingTask: Task<Void, Never>?

    init() {
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let count = await Task.detached(priority: .utility) {
                    TmuxState.readSessionCount()
                }.value
                if self?.sessionCount != count { self?.sessionCount = count }
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    deinit { pollingTask?.cancel() }

    /// Resolved once per process; nil if tmux not found in PATH.
    nonisolated static let tmuxURL: URL? = {
        let candidates = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }()

    nonisolated static func readSessionCount() -> Int {
        guard let url = tmuxURL else { return 0 }
        let proc = Process()
        proc.executableURL = url
        proc.arguments = ["list-sessions"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return 0 }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return 0 }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.split(separator: "\n", omittingEmptySubsequences: true).count
    }
}

// MARK: - View

private struct TmuxWidgetView: View {
    @StateObject private var state = TmuxState()
    let color: Color

    var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text("\(state.sessionCount)")
                .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.labelColor)
                .lineLimit(1)
                .stableMinWidth()
        }
        .nanoPill()
        .animation(Theme.animEase, value: state.sessionCount)
    }
}

// MARK: - Factory

private final class TmuxWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "tmux" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        NanoBarViewBox(AnyView(TmuxWidgetView(color: accentColor)))
    }

    private var accentColor: Color {
        Theme.color(hex: config["color"]) ?? Theme.tmuxColor
    }
}

// MARK: - Entry point

/// Principal class declared in Info.plist via NSPrincipalClass = "TmuxPlugin".
@objc(TmuxPlugin)
public final class TmuxPlugin: NSObject, NanoBarPluginEntry, NanoBarPluginSettingsProvider {
    public var pluginID: String { "tmux" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(TmuxWidgetFactory(config: config))
    }

    public var displayName: String { "Tmux" }
    public func settingsSchema() -> [SettingsField] {[
        SettingsField(key: "color", label: "Icon color", type: .color, defaultValue: Theme.tmuxColor.toHex8() ?? ""),
    ]}
}
