// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeclarativeUIKitCombine",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "DeclarativeUIKitCombine", targets: ["DeclarativeUIKitCombine"])
    ],
    dependencies: [],
    targets: [
        .target(name: "DeclarativeUIKitCombine"),
        .testTarget(name: "DeclarativeUIKitCombineTests", dependencies: ["DeclarativeUIKitCombine"])
    ],
    swiftLanguageVersions: [.v5]
)
