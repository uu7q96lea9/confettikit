# ConfettiKit

A small SwiftUI overlay that celebrates with confetti. Particles are simulated
on the CPU and drawn by Metal in a single instanced draw call, so a 200-particle
burst costs one pipeline switch instead of 200 `CALayer`s.

## Why

Core Animation confetti is easy to start and expensive to keep: every piece is a
layer with its own animation, and a long-lived screen keeps all of them alive.
ConfettiKit runs one `MTKView`, recycles a fixed instance buffer, and pauses
itself when the last particle dies. Shapes are drawn in the fragment shader, so
there are no image assets to ship.

## Requirements

- iOS 16.0 or newer
- Metal-capable device or simulator
- Swift 5.9 toolchain

## Install

Add the package in Xcode with **File > Add Package Dependencies...** and paste
`https://github.com/uu7q96lea9/confettikit`, or add it to `Package.swift`:

```swift
.package(url: "https://github.com/uu7q96lea9/confettikit", from: "1.0.0")
```

## Usage

Increment a counter to fire a burst. The overlay sits above your content,
ignores touches, and starts no work until the first trigger.

```swift
import ConfettiKit
import SwiftUI

struct CheckoutView: View {
    @State private var celebrations = 0

    var body: some View {
        Button("Pay") {
            celebrations += 1
        }
        .confetti(trigger: celebrations, announcement: "Order placed")
    }
}
```

Tune the effect with `ConfettiConfiguration`, or start from `.subtle`:

```swift
.confetti(configuration: .subtle, trigger: celebrations)
```

Bursts are centred on the overlay. `emissionAngle` points up at zero degrees;
`spread`, `speed`, `gravity`, `size`, `lifetime` and `spin` control the rest.
Colors default to the system palette and are resolved against the current trait
collection.

### Accessibility

- The overlay is decorative: it carries `.accessibilityHidden(true)` and never
  becomes a VoiceOver stop.
- With **Reduce Motion** enabled the burst is emitted as a still cloud with no
  velocity or gravity, and fades out in place.
- Pass `announcement:` to post a one-shot VoiceOver announcement; keep the text
  short and only use it when the confetti communicates a real state change.

## Layout

```
Package.swift
Sources/ConfettiKit/
  ConfettiConfiguration.swift  tunables, shapes, presets, Reduce Motion variant
  ConfettiParticle.swift       particle state, integration, deterministic spawner
  ConfettiRenderer.swift       Metal pipeline, instanced quad shader, simulation loop
  ConfettiView.swift           SwiftUI wrapper and `.confetti` modifier
```

## License

MIT. See [LICENSE](LICENSE).
