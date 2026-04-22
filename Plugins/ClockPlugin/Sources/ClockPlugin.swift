import Foundation
import SwiftUI
import NanoBarPluginAPI

// MARK: - Timer interval

/// Returns the refresh interval for the given DateFormatter format string.
/// Formats containing lowercase "ss" (clock seconds) use a 1-second interval;
/// all others use 30 seconds, aligning updates to the minute boundary.
func clockTimerInterval(for format: String) -> Double {
    format.contains("ss") ? 1.0 : 30.0
}

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
        timer?.cancel()
        timer = nil
        let interval = clockTimerInterval(for: formatter.dateFormat ?? "")
        let t = DispatchSource.makeTimerSource(queue: .main)
        let now = Date()
        let secondsToNext = interval - (now.timeIntervalSince1970.truncatingRemainder(dividingBy: interval))
        t.schedule(wallDeadline: .now() + secondsToNext, repeating: interval, leeway: .milliseconds(interval < 2 ? 10 : 500))
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
            .nanoPill()
        }
    }
}

// MARK: - Factory

private final class ClockWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "clock" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        let format = config["format"]!
        let color  = Theme.color(hex: config["color"]!) ?? Theme.calendarColor
        return NanoBarViewBox(AnyView(ClockWidgetView(format: format, color: color)))
    }
}

// MARK: - Entry point

@objc(ClockPlugin)
public final class ClockPlugin: NSObject, NanoBarPluginEntry, NanoBarPluginSettingsProvider {
    public var pluginID: String { "clock" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(ClockWidgetFactory(config: resolvedSettings(config)))
    }

    public var displayName: String { "Clock" }
    public func settingsSchema() -> [SettingsField] {[
        SettingsField(key: "format",  label: "Date format",  type: .text,  defaultValue: "EEE dd MMM HH:mm"),
        SettingsField(key: "color",   label: "Icon color",   type: .color, defaultValue: Theme.calendarColor.toHex8() ?? ""),
    ]}
}
