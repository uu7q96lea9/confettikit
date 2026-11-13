import UIKit

/// Ready-made configurations for common celebrations.
///
/// A preset is just a `ConfettiConfiguration`; take `configuration` and hand it
/// to `.confetti(configuration:trigger:)`. `resolved(reducingMotion:)` applies
/// the still variant for you.
public struct ConfettiPreset: Sendable {
    public let configuration: ConfettiConfiguration

    public init(configuration: ConfettiConfiguration) {
        self.configuration = configuration
    }

    /// Uses the still burst when Reduce Motion is on.
    public func resolved(reducingMotion: Bool) -> ConfettiConfiguration {
        reducingMotion ? configuration.stillVariant : configuration
    }

    /// Classic paper confetti that falls across the whole width.
    public static let celebration = ConfettiPreset(configuration: .celebration)

    /// Dense, bright stars for a short "nice one" moment.
    public static let sparkle = ConfettiPreset(configuration: ConfettiConfiguration(
        particleCount: 64,
        colors: [.systemYellow, .systemOrange, .white, .systemPink],
        shapes: ConfettiShapeSet.sparkle.expanded(),
        spread: .degrees(40),
        speed: 240...520,
        gravity: CGVector(dx: 0, dy: 520),
        size: 5...11,
        lifetime: 1.0...1.8,
        spin: -180...180
    ))

    /// Slow, heavy rectangles in autumn tones. Reads well on light backgrounds.
    public static let autumnRain = ConfettiPreset(configuration: ConfettiConfiguration(
        particleCount: 120,
        colors: [.systemOrange, .systemBrown, .systemRed, .systemYellow],
        shapes: ConfettiShapeSet.classic.expanded(),
        spread: .degrees(70),
        speed: 160...380,
        gravity: CGVector(dx: -40, dy: 420),
        size: 7...13,
        lifetime: 2.2...3.4,
        spin: -220...220,
        drag: 1.4
    ))

    /// Quiet monochrome burst for secondary confirmations.
    public static let monochrome = ConfettiPreset(configuration: ConfettiConfiguration(
        particleCount: 48,
        colors: [.white, .systemGray4, .systemGray2],
        shapes: ConfettiShapeSet.classic.expanded(count: 8),
        speed: 200...420,
        size: 5...10,
        lifetime: 0.9...1.5,
        spin: -120...120
    ))
}
