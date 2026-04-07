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

    private let broadcaster = MonitorBroadcaster<BatteryInfo>()

    public func register(_ observer: @escaping @MainActor (BatteryInfo) -> Void) {
        broadcaster.register(observer)
    }

    private var loopSource: CFRunLoopSource?
    private var wakeObserver: NSObjectProtocol?

    private init() {}

    public func start() {
        refresh()
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let rawSource = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue().refresh()
        }, ctx)
        loopSource = rawSource?.takeRetainedValue()
        if let source = loopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        broadcaster.notify(Self.readBattery())
    }

    private static func readBattery() -> BatteryInfo {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)
                    .takeUnretainedValue() as? [String: Any] else { continue }
            let pct = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
            let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
            return BatteryInfo(percentage: pct, isCharging: state == kIOPSACPowerValue)
        }
        return BatteryInfo(percentage: 100, isCharging: false)
    }
}
