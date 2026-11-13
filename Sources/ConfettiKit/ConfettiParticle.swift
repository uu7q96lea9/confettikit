import CoreGraphics
import simd

/// One simulated particle. Particles live in view coordinates; the renderer
/// copies them into a Metal instance buffer every frame.
struct ConfettiParticle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var rotation: Float
    var spin: Float
    var size: Float
    var colorIndex: Int
    var shape: ConfettiShape
    var age: Float
    var lifetime: Float

    var isAlive: Bool {
        age < lifetime
    }

    /// Opacity ramp: quick fade-in, longer fade-out.
    var alpha: Float {
        let fadeIn = min(age / 0.08, 1)
        let fadeOut = min((lifetime - age) / 0.45, 1)
        return max(min(fadeIn, fadeOut), 0)
    }

    mutating func update(deltaTime: Float, gravity: SIMD2<Float>, drag: Float) {
        velocity += gravity * deltaTime
        velocity /= 1 + max(drag, 0) * deltaTime
        position += velocity * deltaTime
        rotation += spin * deltaTime
        age += deltaTime
    }
}

/// Deterministic PRNG so burst layouts are reproducible in tests and demos.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in [0, 1).
    mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }

    mutating func value(in range: ClosedRange<Float>) -> Float {
        let low = range.lowerBound
        let high = range.upperBound
        return low + (high - low) * unit()
    }

    mutating func int(below limit: Int) -> Int {
        Int(next() % UInt64(limit))
    }
}

enum ConfettiSpawner {
    private static let originJitter: Float = 8

    /// Builds a burst. With Reduce Motion enabled the particles are scattered
    /// over a small disc instead of being launched, which reads as a still
    /// snapshot of the effect.
    static func burst(
        from origin: SIMD2<Float>,
        configuration: ConfettiConfiguration,
        reduceMotion: Bool,
        rng: inout SplitMix64
    ) -> [ConfettiParticle] {
        let shapes = configuration.shapes
        let colorCount = configuration.colors.count
        let halfSpread = Float(configuration.spread.radians) / 2
        let baseAngle = Float(configuration.emissionAngle.radians)
        let speeds = configuration.speed.floats
        let sizes = configuration.size.floats
        let lifetimes = configuration.lifetime.floats
        let spins = configuration.spin.floats

        return (0..<configuration.particleCount).map { _ in
            let angle = baseAngle + rng.value(in: -halfSpread...halfSpread)
            let speed = rng.value(in: speeds)
            let offsetRadius = reduceMotion ? rng.value(in: 0...110) : 0
            let offsetAngle = rng.unit() * 2 * Float.pi

            return ConfettiParticle(
                position: origin + SIMD2(
                    cos(offsetAngle) * offsetRadius + rng.value(in: -originJitter...originJitter),
                    sin(offsetAngle) * offsetRadius + rng.value(in: -originJitter...originJitter)
                ),
                velocity: SIMD2(sin(angle) * speed, -cos(angle) * speed),
                rotation: rng.value(in: 0...(2 * Float.pi)),
                spin: rng.value(in: spins) * Float.pi / 180,
                size: rng.value(in: sizes),
                colorIndex: rng.int(below: colorCount),
                shape: shapes[rng.int(below: shapes.count)],
                age: 0,
                lifetime: max(rng.value(in: lifetimes), 0.2)
            )
        }
    }
}
