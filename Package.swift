// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwakeLoop",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AwakeLoop", targets: ["AwakeLoop"])
    ],
    targets: [
        .executableTarget(name: "AwakeLoop")
    ],
    swiftLanguageModes: [.v5]
)