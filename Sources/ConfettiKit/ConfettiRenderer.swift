import CoreGraphics
import Metal
import MetalKit
import QuartzCore
import UIKit
import simd

/// Per-particle payload copied to the GPU. The layout mirrors `Instance` in
/// `ConfettiShaders.source`; keep them in sync.
struct ConfettiInstance {
    /// x, y in points plus opacity in z.
    var positionAndAlpha: SIMD4<Float>
    /// Edge length in points and rotation in radians.
    var sizeAndRotation: SIMD2<Float>
    /// Linear RGB plus the `ConfettiShape` raw value in w.
    var colorAndShape: SIMD4<Float>
}

enum ConfettiRendererError: Error {
    case unavailableDevice
}

enum ConfettiShaders {
    static let source = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct Instance {
        float4 positionAndAlpha;
        float2 sizeAndRotation;
        float4 colorAndShape;
    };

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
        float4 color;
        uint shape [[flat]];
    };

    constant float2 corners[6] = {
        float2(-0.5, -0.5), float2(0.5, -0.5), float2(-0.5, 0.5),
        float2(-0.5, 0.5), float2(0.5, -0.5), float2(0.5, 0.5)
    };

    vertex VertexOut confetti_vertex(uint vertexID [[vertex_id]],
                                     uint instanceID [[instance_id]],
                                     const device Instance *instances [[buffer(1)]],
                                     constant float2 &viewport [[buffer(2)]]) {
        Instance instance = instances[instanceID];
        float2 corner = corners[vertexID] * instance.sizeAndRotation.x;
        float angle = instance.sizeAndRotation.y;
        float cosine = cos(angle);
        float sine = sin(angle);
        float2 rotated = float2(corner.x * cosine - corner.y * sine,
                                corner.x * sine + corner.y * cosine);
        float2 pixel = instance.positionAndAlpha.xy + rotated;
        float2 clip = float2(pixel.x / viewport.x * 2.0 - 1.0,
                             1.0 - pixel.y / viewport.y * 2.0);

        VertexOut out;
        out.position = float4(clip, 0.0, 1.0);
        out.uv = corners[vertexID];
        out.color = float4(instance.colorAndShape.rgb, instance.positionAndAlpha.z);
        out.shape = uint(instance.colorAndShape.w);
        return out;
    }

    fragment float4 confetti_fragment(VertexOut in [[stage_in]]) {
        float2 p = in.uv;
        float radius = length(p);
        float mask;

        switch (in.shape) {
        case 0:
            mask = 1.0;
            break;
        case 1:
            mask = 1.0 - smoothstep(0.48, 0.5, radius);
            break;
        case 2:
            mask = step(abs(p.x) * 1.7, p.y + 0.5);
            break;
        default:
            float angle = atan2(p.y, p.x);
            float starRadius = 0.5 * (0.62 + 0.38 * cos(5.0 * angle));
            mask = 1.0 - smoothstep(0.0, 0.03, radius - starRadius);
            break;
        }

        if (mask < 0.02) {
            discard_fragment();
        }
        return float4(in.color.rgb, in.color.a * mask);
    }
    """#
}

/// Owns the Metal pipeline and the particle simulation for one `MTKView`.
/// The view starts paused and is only resumed for the lifetime of a burst.
final class ConfettiRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let colors: [SIMD4<Float>]

    private var instanceBuffer: MTLBuffer?
    private var capacity = 0
    private var particles: [ConfettiParticle] = []
    private var rng = SplitMix64(seed: 0x0C0F_FEE5)
    private var lastTimestamp: CFTimeInterval = 0
    private weak var view: MTKView?
    private var reduceMotion: Bool
    private var configuration: ConfettiConfiguration

    init(view: MTKView, configuration: ConfettiConfiguration, reduceMotion: Bool) throws {
        guard let device = view.device, let queue = device.makeCommandQueue() else {
            throw ConfettiRendererError.unavailableDevice
        }

        self.device = device
        self.commandQueue = queue
        self.view = view
        self.configuration = configuration
        self.reduceMotion = reduceMotion
        self.colors = configuration.colors.map { color in
            var red: CGFloat = 1
            var green: CGFloat = 1
            var blue: CGFloat = 1
            var alpha: CGFloat = 1
            color.resolvedColor(with: view.traitCollection)
                .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return SIMD4(Float(red), Float(green), Float(blue), Float(alpha))
        }

        let library = try device.makeLibrary(source: ConfettiShaders.source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "confetti_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "confetti_fragment")
        if let attachment = descriptor.colorAttachments[0] {
            attachment.pixelFormat = view.colorPixelFormat
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.sourceAlphaBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)

        super.init()
        ensureCapacity(configuration.particleCount)
        view.delegate = self
    }

    func update(configuration: ConfettiConfiguration, reduceMotion: Bool) {
        self.configuration = configuration
        self.reduceMotion = reduceMotion
        ensureCapacity(configuration.particleCount)
    }

    /// Emits one burst centred on `point` in view coordinates.
    func burst(at point: CGPoint) {
        guard let view else { return }
        let config = reduceMotion ? configuration.stillVariant : configuration
        ensureCapacity(config.particleCount)
        particles = ConfettiSpawner.burst(
            from: SIMD2(Float(point.x), Float(point.y)),
            configuration: config,
            reduceMotion: reduceMotion,
            rng: &rng
        )
        lastTimestamp = 0
        view.isPaused = false
    }

    private func ensureCapacity(_ count: Int) {
        guard count > capacity else { return }
        guard let buffer = device.makeBuffer(
            length: MemoryLayout<ConfettiInstance>.stride * count,
            options: .storageModeShared
        ) else { return }
        capacity = count
        instanceBuffer = buffer
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let instanceBuffer, !particles.isEmpty else {
            view.isPaused = true
            return
        }
        guard let descriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable else {
            return
        }

        let now = CACurrentMediaTime()
        let delta = lastTimestamp == 0 ? Float(1.0 / 60.0) : Float(min(now - lastTimestamp, 0.05))
        lastTimestamp = now

        let gravity = SIMD2(Float(configuration.gravity.dx), Float(configuration.gravity.dy))
        let drag = Float(configuration.drag)
        for index in particles.indices {
            particles[index].update(deltaTime: delta, gravity: gravity, drag: drag)
        }

        let height = Float(view.bounds.height)
        particles.removeAll { !$0.isAlive || $0.position.y > height + 60 }

        let count = particles.count
        guard count > 0 else {
            view.isPaused = true
            lastTimestamp = 0
            return
        }

        let instances = instanceBuffer.contents().bindMemory(to: ConfettiInstance.self, capacity: capacity)
        for (index, particle) in particles.enumerated() {
            let color = colors[particle.colorIndex]
            instances[index] = ConfettiInstance(
                positionAndAlpha: SIMD4(particle.position.x, particle.position.y, particle.alpha, 0),
                sizeAndRotation: SIMD2(particle.size, particle.rotation),
                colorAndShape: SIMD4(color.x, color.y, color.z, Float(particle.shape.rawValue))
            )
        }

        let viewport = SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height))
        guard viewport.x > 1, viewport.y > 1 else { return }

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD2<Float>>.stride, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: count)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
