// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Orbin",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Orbin", targets: ["Orbin"])
    ],
    targets: [
        .executableTarget(
            name: "Orbin",
            path: "Sources/Orbin"
        )
    ]
)
