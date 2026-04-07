import Foundation

/// Fires every 30 seconds, aligned to :00 and :30 boundaries.
public final class ClockMonitor: @unchecked Sendable {
    public static let shared = ClockMonitor()

    private let broadcaster = MonitorBroadcaster<String>()

    public func register(_ observer: @escaping @MainActor (String) -> Void) {
        broadcaster.register(observer)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE dd MMM HH:mm"
        return f
    }()

    private var timer: DispatchSourceTimer?

    private init() {}

    public func start() {
        tick()
        scheduleTimer()
    }

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
        let text = ClockMonitor.formatter.string(from: Date())
        broadcaster.notify(text)
    }
}
