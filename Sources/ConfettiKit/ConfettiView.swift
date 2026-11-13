import MetalKit
import SwiftUI
import UIKit

/// A decorative confetti overlay. Point it at a triggering counter and the
/// view emits one burst whenever that counter changes.
///
/// The view is transparent, does not take part in hit testing, and is hidden
/// from VoiceOver; use `announcement` to post a spoken cue when needed.
public struct ConfettiView: UIViewRepresentable {
    public var configuration: ConfettiConfiguration
    public var trigger: Int
    public var announcement: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        configuration: ConfettiConfiguration = .celebration,
        trigger: Int,
        announcement: String? = nil
    ) {
        self.configuration = configuration
        self.trigger = trigger
        self.announcement = announcement
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.isOpaque = false
        view.backgroundColor = .clear
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        context.coordinator.attach(to: view, configuration: configuration, reduceMotion: reduceMotion)
        return view
    }

    public func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.apply(
            configuration: configuration,
            reduceMotion: reduceMotion,
            trigger: trigger,
            announcement: announcement,
            to: view
        )
    }

    public final class Coordinator {
        private var renderer: ConfettiRenderer?
        private var lastTrigger: Int?
        private var announcement: String?

        func attach(to view: MTKView, configuration: ConfettiConfiguration, reduceMotion: Bool) {
            do {
                renderer = try ConfettiRenderer(
                    view: view,
                    configuration: configuration,
                    reduceMotion: reduceMotion
                )
            } catch {
                renderer = nil
            }
        }

        func apply(
            configuration: ConfettiConfiguration,
            reduceMotion: Bool,
            trigger: Int,
            announcement: String?,
            to view: MTKView
        ) {
            renderer?.update(configuration: configuration, reduceMotion: reduceMotion)
            self.announcement = announcement

            guard lastTrigger != trigger else { return }
            lastTrigger = trigger
            guard trigger != 0 else { return }

            renderer?.burst(at: CGPoint(x: view.bounds.midX, y: view.bounds.midY))
            if let announcement, !announcement.isEmpty {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
    }
}

public extension View {
    /// Layers a confetti burst over the receiver without affecting layout or
    /// touch handling.
    func confetti(
        configuration: ConfettiConfiguration = .celebration,
        trigger: Int,
        announcement: String? = nil
    ) -> some View {
        overlay {
            ConfettiView(configuration: configuration, trigger: trigger, announcement: announcement)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
