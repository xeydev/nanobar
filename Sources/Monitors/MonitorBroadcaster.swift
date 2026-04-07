import Foundation

final class MonitorBroadcaster<T: Sendable>: @unchecked Sendable {
    private var observers: [@MainActor (T) -> Void] = []

    func register(_ observer: @escaping @MainActor (T) -> Void) {
        observers.append(observer)
    }

    func notify(_ value: T) {
        let obs = observers
        DispatchQueue.main.async { obs.forEach { $0(value) } }
    }
}
