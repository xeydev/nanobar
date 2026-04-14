import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - State

@MainActor
private final class ClockState: ObservableObject, @unchecked Sendable {
    @Published var text: String = ""

    private let formatter: DateFormatter
    private var timer: DispatchSourceTimer?

    init(format: String) {
        let f = DateFormatter()
        f.dateFormat = format
        self.formatter = f
        tick()
        scheduleTimer()
    }

    deinit { timer?.cancel() }

    private func scheduleTimer() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        let now = Date()
        let secondsToNext = 30.0 - (now.timeIntervalSince1970.truncatingRemainder(dividingBy: 30.0))
        t.schedule(wallDeadline: .now() + secondsToNext, repeating: 30.0, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        let new = formatter.string(from: Date())
        if new != text { text = new }
    }
}

// MARK: - View

private struct ClockWidgetView: View {
    @StateObject private var state: ClockState
    let color: Color

    init(format: String, color: Color) {
        _state = StateObject(wrappedValue: ClockState(format: format))
        self.color = color
    }

    @ViewBuilder
    var body: some View {
        if !state.text.isEmpty {
            HStack(spacing: Theme.iconLabelSpacing) {
                Image(systemName: "calendar")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(color)
                Text(state.text)
                    .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.labelColor)
                    .lineLimit(1)
                    .stableMinWidth()
            }
            .glassPill()
        }
    }
}

// MARK: - Factory

private final class ClockWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "clock" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        let format = config["format"] ?? "EEE dd MMM HH:mm"
        let color  = Theme.color(hex: config["color"]) ?? Theme.calendarColor
        return NanoBarViewBox(AnyView(ClockWidgetView(format: format, color: color)))
    }
}

// MARK: - Entry point

@objc(ClockPlugin)
public final class ClockPlugin: NSObject, NanoBarPluginEntry {
    public var pluginID: String { "clock" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(ClockWidgetFactory(config: config))
    }
}
