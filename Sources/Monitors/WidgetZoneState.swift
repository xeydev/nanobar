import Foundation

// MARK: - WidgetZoneState

/// Pure-value model for the three widget zones.
/// Encapsulates all mutation logic so it can be tested independently of SwiftUI.
public struct WidgetZoneState: Sendable {
    public var left:   [String]
    public var center: [String]
    public var right:  [String]

    public init(left: [String] = [], center: [String] = [], right: [String] = []) {
        self.left = left; self.center = center; self.right = right
    }

    // MARK: - Queries

    /// Plugin IDs that are not yet placed in any zone, preserving the order of `all`.
    public func available(from all: [String]) -> [String] {
        let placed = Set(left + center + right)
        return all.filter { !placed.contains($0) }
    }

    // MARK: - Mutations

    public mutating func moveUp(_ id: String, in zone: String) {
        mutate(zone) { arr in
            guard let i = arr.firstIndex(of: id), i > 0 else { return }
            arr.swapAt(i, i - 1)
        }
    }

    public mutating func moveDown(_ id: String, in zone: String) {
        mutate(zone) { arr in
            guard let i = arr.firstIndex(of: id), i < arr.count - 1 else { return }
            arr.swapAt(i, i + 1)
        }
    }

    public mutating func remove(_ id: String, from zone: String) {
        mutate(zone) { arr in arr.removeAll { $0 == id } }
    }

    public mutating func add(_ id: String, to zone: String) {
        mutate(zone) { arr in arr.append(id) }
    }

    public mutating func moveBetween(_ id: String, from source: String, to destination: String) {
        remove(id, from: source)
        add(id, to: destination)
    }

    /// Subscript read — returns the zone array for a zone key string.
    public subscript(zone: String) -> [String] {
        switch zone {
        case "left":   return left
        case "center": return center
        default:       return right
        }
    }

    /// Directly replace a zone's array (used by onMove drag-and-drop).
    public mutating func mutateZone(_ zone: String, to items: [String]) {
        switch zone {
        case "left":   left   = items
        case "center": center = items
        default:       right  = items
        }
    }

    // MARK: - Private

    private mutating func mutate(_ zone: String, _ transform: (inout [String]) -> Void) {
        switch zone {
        case "left":   transform(&left)
        case "center": transform(&center)
        default:       transform(&right)
        }
    }
}
