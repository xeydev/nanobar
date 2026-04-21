import AppKit
import Foundation
import IOKit.ps
import SwiftUI
import NanoBarPluginAPI

// MARK: - Battery info

private struct BatteryInfo: Sendable, Equatable {
    let percentage: Int
    let isCharging: Bool

    static func read() -> BatteryInfo {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)
                    .takeUnretainedValue() as? [String: Any] else { continue }
            let pct   = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
            let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
            return BatteryInfo(percentage: pct, isCharging: state == kIOPSACPowerValue)
        }
        return BatteryInfo(percentage: 100, isCharging: false)
    }
}

// MARK: - State

@MainActor
private final class BatteryState: ObservableObject, @unchecked Sendable {
    @Published var info = BatteryInfo(percentage: 100, isCharging: false)

    nonisolated(unsafe) private var loopSource: CFRunLoopSource?
    nonisolated(unsafe) private var wakeObserver: NSObjectProtocol?

    init() {
        refresh()
        // passUnretained: BatteryState is @MainActor — deinit and the IOKit RunLoop source both
        // operate on the main run loop, so CFRunLoopRemoveSource in deinit serializes before any
        // further callback. passRetained would create a retain cycle (passRetained keeps ARC count
        // ≥ 1 → deinit never runs → release in deinit unreachable → permanent leak).
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let rawSource = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            // Source fires on the main run loop; DispatchQueue.main.async is redundant but
            // makes the @MainActor bridge explicit and guards against future run-loop changes.
            DispatchQueue.main.async {
                Unmanaged<BatteryState>.fromOpaque(ctx).takeUnretainedValue().refresh()
            }
        }, ctx)
        loopSource = rawSource?.takeRetainedValue()
        if let source = loopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // queue: .main guarantees main thread; assumeIsolated bridges to @MainActor.
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    deinit {
        wakeObserver.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        if let source = loopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
    }

    private func refresh() {
        let new = BatteryInfo.read()
        if new != info { info = new }
    }
}

// MARK: - View

private struct BatteryWidgetView: View {
    @StateObject private var state = BatteryState()
    let colors: (normal: Color, warn: Color, med: Color, low: Color)

    private var info: BatteryInfo { state.info }

    private var color: Color {
        if info.isCharging || info.percentage > 75 { return colors.normal }
        if info.percentage > 50                    { return colors.warn   }
        if info.percentage > 25                    { return colors.med    }
        return colors.low
    }

    private var symbolName: String {
        if info.isCharging { return "battery.100percent.bolt" }
        switch info.percentage {
        case ..<13:  return "battery.0percent"
        case ..<38:  return "battery.25percent"
        case ..<63:  return "battery.50percent"
        case ..<88:  return "battery.75percent"
        default:     return "battery.100percent"
        }
    }

    var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            Image(systemName: symbolName)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 26, height: 14)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
            Text("\(info.percentage)%")
                .font(.system(size: Theme.labelSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.labelColor)
                .lineLimit(1)
                .stableMinWidth()
        }
        .glassPill()
        .animation(.easeInOut(duration: 0.4), value: info.isCharging)
        .animation(.easeInOut(duration: 0.4), value: symbolName)
    }
}

// MARK: - Factory

private final class BatteryWidgetFactory: NSObject, NanoBarWidgetFactory {
    private let config: [String: String]
    init(config: [String: String]) { self.config = config }

    var widgetID: String { "battery" }

    @MainActor func makeViewBox() -> NanoBarViewBox {
        let colors = (
            normal: Theme.color(hex: config["color"])     ?? Theme.batteryGreen,
            warn:   Theme.color(hex: config["warnColor"]) ?? Theme.batteryYellow,
            med:    Theme.color(hex: config["medColor"])  ?? Theme.batteryOrange,
            low:    Theme.color(hex: config["lowColor"])  ?? Theme.batteryRed
        )
        return NanoBarViewBox(AnyView(BatteryWidgetView(colors: colors)))
    }
}

// MARK: - Entry point

@objc(BatteryPlugin)
public final class BatteryPlugin: NSObject, NanoBarPluginEntry {
    public var pluginID: String { "battery" }
    @MainActor public func registerWidgets(with registry: any NanoBarWidgetRegistry, config: [String: String]) {
        registry.register(BatteryWidgetFactory(config: config))
    }
}
