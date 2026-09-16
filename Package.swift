// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TidyTrailCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "TidyTrailCore", targets: ["TidyTrailCore"])
    ],
    targets: [
        .target(name: "TidyTrailCore", path: "Sources/TidyTrailCore"),
        .testTarget(name: "TidyTrailCoreTests", dependencies: ["TidyTrailCore"], path: "Tests/TidyTrailCoreTests")
    ]
)
