// swift-tools-version: 6.2
import PackageDescription

// Pure-Swift core (no Muse SDK): electrode geometry, activity scoring, topomap rendering,
// brain-mesh loading and a synthetic headband. Testable with `swift test`.
let package = Package(
    name: "BrainwaveKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "BrainwaveKit", targets: ["BrainwaveKit"])],
    targets: [
        .target(name: "BrainwaveKit", resources: [.process("Localizable.xcstrings")]),
        .testTarget(name: "BrainwaveKitTests", dependencies: ["BrainwaveKit"]),
    ]
)
