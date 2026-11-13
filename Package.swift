// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConfettiKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "ConfettiKit", targets: ["ConfettiKit"])
    ],
    targets: [
        .target(name: "ConfettiKit")
    ]
)
