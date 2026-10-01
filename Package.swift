// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeclarativeCombine",
    platforms: [.iOS(.v13), .macOS(.v11)],
    products: [
        .library(name: "DeclarativeCombine", targets: ["DeclarativeCombine"])
    ],
    dependencies: [],
    targets: [
        .target(name: "DeclarativeCombine"),
        .testTarget(name: "DeclarativeCombineTests", dependencies: ["DeclarativeCombine"])
    ],
    swiftLanguageVersions: [.v5]
)
