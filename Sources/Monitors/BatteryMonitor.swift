import Foundation
import IOKit.ps
import AppKit

public struct BatteryInfo: Sendable {
    public let percentage: Int
    public let isCharging: Bool
    public init(percentage: Int, isCharging: Bool) {
        self.percentage = percentage
        self.isCharging = isCharging
    }
}

/// Push-based battery monitor using IOKit. Zero polling.
public final class BatteryMonitor: @unchecked Sendable {
    public static let shared = BatteryMonitor()
    public var onChange: (@MainActor (BatteryInfo) -> Void)?

    private var loopSource: CFRunLoopSource?
    private var wakeObserver: NSObjectProtocol?

    private init() {}

    public func start() {
        // Initial read
        refresh()

        // IOKit push notifications for power source changes
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let rawSource = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.refresh()
        }, ctx)
        loopSource = rawSource?.takeRetainedValue()

        if let source = loopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        // Also refresh on system wake
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let info = Self.readBattery()
        let cb = onChange
        DispatchQueue.main.async {
            cb?(info)
        }
    }

    private static func readBattery() -> BatteryInfo {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)
                    .takeUnretainedValue() as? [String: Any] else { continue }

            let pct = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
            let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
            let isCharging = (state == kIOPSACPowerValue)
            return BatteryInfo(percentage: pct, isCharging: isCharging)
        }

        return BatteryInfo(percentage: 100, isCharging: false)
    }
}
