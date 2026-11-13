import CoreGraphics
import Foundation

/// A weighted mix of `ConfettiShape` values.
///
/// The renderer picks shapes uniformly from the array a burst is configured
/// with, so weighting is expressed by expanding the mix into a repeated array
/// once instead of rolling a dice per particle.
public struct ConfettiShapeSet: Sendable {
    public struct Entry: Sendable {
        public let shape: ConfettiShape
        public let weight: Double

        public init(_ shape: ConfettiShape, weight: Double) {
            self.shape = shape
            self.weight = max(weight, 0)
        }
    }

    private let entries: [Entry]

    public init(_ entries: [Entry]) {
        precondition(!entries.isEmpty, "a shape set needs at least one entry")
        precondition(entries.contains { $0.weight > 0 }, "at least one entry needs a positive weight")
        self.entries = entries
    }

    /// Flattens the weights into `count` slots. Every positive entry gets at
    /// least one slot so a preset never silently drops a shape.
    public func expanded(count: Int = 12) -> [ConfettiShape] {
        precondition(count > 0, "slot count must be positive")
        let total = entries.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [entries[0].shape] }

        var shapes: [ConfettiShape] = []
        shapes.reserveCapacity(count)
        for entry in entries where entry.weight > 0 {
            let share = Int((entry.weight / total * Double(count)).rounded())
            shapes.append(contentsOf: repeatElement(entry.shape, count: max(share, 1)))
        }
        return shapes
    }

    /// Mostly rectangles with a few circles, closest to classic paper confetti.
    public static let classic = ConfettiShapeSet([
        Entry(.rectangle, weight: 7),
        Entry(.circle, weight: 2),
        Entry(.triangle, weight: 1)
    ])

    /// Stars only, for short rewards where density matters.
    public static let stars = ConfettiShapeSet([Entry(.star, weight: 1)])

    /// Circles and stars with no paper shapes.
    public static let sparkle = ConfettiShapeSet([
        Entry(.star, weight: 3),
        Entry(.circle, weight: 2)
    ])
}

public extension ConfettiShape {
    /// A point-in-shape test used by previews and by the shape atlas in the
    /// shader. Coordinates are normalised to the unit quad, centre at zero.
    func contains(_ point: CGPoint) -> Bool {
        switch self {
        case .rectangle:
            return abs(point.x) <= 0.5 && abs(point.y) <= 0.5
        case .circle:
            return hypot(point.x, point.y) <= 0.5
        case .triangle:
            return abs(point.x) * 1.7 <= point.y + 0.5
        case .star:
            let radius = hypot(point.x, point.y)
            let angle = atan2(point.y, point.x)
            let limit = 0.5 * (0.62 + 0.38 * cos(5 * angle))
            return radius <= limit
        }
    }
}
