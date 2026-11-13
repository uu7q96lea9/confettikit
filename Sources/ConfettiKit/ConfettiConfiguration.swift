import CoreGraphics
import SwiftUI

/// The shapes a particle can take. Raw values index the branching table in
/// `ConfettiShaders.source`, so append new cases at the end and extend the
/// shader switch in the same commit.
public enum ConfettiShape: UInt32, CaseIterable, Sendable {
    case rectangle = 0
    case circle = 1
    case triangle = 2
    case star = 3
}

/// Tunables for one confetti burst. All distances are in points, all
/// durations in seconds.
public struct ConfettiConfiguration: Sendable {
    /// Number of particles emitted per burst. The renderer allocates one
    /// instance per particle up front, so large values cost memory, not CPU.
    public var particleCount: Int
    public var colors: [UIColor]
    public var shapes: [ConfettiShape]
    /// Direction of the burst in view coordinates, where zero points up.
    public var emissionAngle: Angle
    /// Half-width of the emission cone.
    public var spread: Angle
    public var speed: ClosedRange<CGFloat>
    public var gravity: CGVector
    /// Edge length of a particle in points.
    public var size: ClosedRange<CGFloat>
    public var lifetime: ClosedRange<TimeInterval>
    /// Spin in degrees per second.
    public var spin: ClosedRange<CGFloat>
    /// Velocity damping factor; zero means no air resistance.
    public var drag: CGFloat

    public init(
        particleCount: Int = 180,
        colors: [UIColor] = ConfettiConfiguration.defaultColors,
        shapes: [ConfettiShape] = ConfettiShape.allCases,
        emissionAngle: Angle = .degrees(0),
        spread: Angle = .degrees(28),
        speed: ClosedRange<CGFloat> = 380...920,
        gravity: CGVector = CGVector(dx: 0, dy: 900),
        size: ClosedRange<CGFloat> = 6...14,
        lifetime: ClosedRange<TimeInterval> = 1.2...2.4,
        spin: ClosedRange<CGFloat> = -540...540,
        drag: CGFloat = 0.9
    ) {
        precondition(particleCount > 0, "a burst needs at least one particle")
        precondition(!colors.isEmpty, "at least one color is required")
        precondition(!shapes.isEmpty, "at least one shape is required")
        self.particleCount = particleCount
        self.colors = colors
        self.shapes = shapes
        self.emissionAngle = emissionAngle
        self.spread = spread
        self.speed = speed
        self.gravity = gravity
        self.size = size
        self.lifetime = lifetime
        self.spin = spin
        self.drag = drag
    }

    public static let celebration = ConfettiConfiguration()

    /// Feathered variant for pull-to-refresh style feedback.
    public static let subtle = ConfettiConfiguration(
        particleCount: 70,
        speed: 220...480,
        size: 4...9,
        lifetime: 0.9...1.6,
        spin: -240...240
    )

    public static let defaultColors: [UIColor] = [
        .systemPink,
        .systemOrange,
        .systemYellow,
        .systemTeal,
        .systemIndigo,
        .systemPurple
    ]
}

extension ClosedRange where Bound: BinaryFloatingPoint {
    /// Converts a configuration range into the Float domain the simulation uses.
    var floats: ClosedRange<Float> {
        Float(lowerBound)...Float(upperBound)
    }
}

extension ConfettiConfiguration {
    /// Scales particle count and motion for Reduce Motion. The burst becomes
    /// a still cloud that fades out rather than a moving one.
    public var stillVariant: ConfettiConfiguration {
        var copy = self
        copy.particleCount = max(particleCount / 2, 1)
        copy.speed = 0...0
        copy.gravity = .zero
        copy.spin = 0...0
        copy.lifetime = lifetime.lowerBound...lifetime.lowerBound
        return copy
    }
}
