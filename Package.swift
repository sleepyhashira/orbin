// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacReorganize",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacReorganize", targets: ["MacReorganize"])
    ],
    targets: [
        .executableTarget(
            name: "MacReorganize",
            path: "Sources/MacReorganize"
        )
    ]
)
