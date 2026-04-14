import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - Live state

/// Polls `tmux list-sessions` every 5 seconds and publishes the count.
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
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    deinit { pollingTask?.cancel() }

    nonisolated static func readSessionCount() -> Int {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["tmux", "list-sessions"]
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
        .glassPill()
        .animation(.easeInOut(duration: 0.3), value: state.sessionCount)
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
        Theme.color(hex: config["color"]) ?? Color(red: 0.678, green: 0.918, blue: 0.686)
    }
}

// MARK: - Entry point

/// Principal class declared in Info.plist via NSPrincipalClass = "TmuxPlugin".
@objc(TmuxPlugin)
public final class TmuxPlugin: NSObject, NanoBarPluginEntry {
    public var pluginID: String { "tmux" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(TmuxWidgetFactory(config: config))
    }
}
