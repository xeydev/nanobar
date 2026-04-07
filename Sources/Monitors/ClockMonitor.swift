import Foundation

/// Fires every 30 seconds, aligned to :00 and :30 boundaries.
public final class ClockMonitor: @unchecked Sendable {
    public static let shared = ClockMonitor()
    public var onChange: (@MainActor (String) -> Void)?

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE dd MMM HH:mm"
        return f
    }()

    private var timer: DispatchSourceTimer?

    private init() {}

    public func start() {
        tick() // immediate first value
        scheduleTimer()
    }

    private func scheduleTimer() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        // Align to next :00 or :30 boundary
        let now = Date()
        let secondsToNext = 30.0 - (now.timeIntervalSince1970.truncatingRemainder(dividingBy: 30.0))
        t.schedule(
            wallDeadline: .now() + secondsToNext,
            repeating: 30.0,
            leeway: .milliseconds(500)
        )
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        let text = ClockMonitor.formatter.string(from: Date())
        let cb = onChange
        DispatchQueue.main.async {
            cb?(text)
        }
    }
}
