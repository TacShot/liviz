// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "LiveViz",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LiveViz", targets: ["LiveViz"])
    ],
    targets: [
        .executableTarget(
            name: "LiveViz",
            path: "Sources/LiveViz"
        )
    ]
)
