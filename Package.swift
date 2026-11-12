// swift-tools-version: 5.9
import PackageDescription

let strictConcurrency: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "StoreScope",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "StoreScope", targets: ["StoreScope"]),
        .library(name: "StoreScopeUI", targets: ["StoreScopeUI"]),
        .library(name: "StoreScopeCore", targets: ["StoreScopeCore"])
    ],
    targets: [
        .target(name: "StoreScopeCore", swiftSettings: strictConcurrency),
        .target(name: "StoreScopeUI", dependencies: ["StoreScopeCore"], swiftSettings: strictConcurrency),
        .target(name: "StoreScope", dependencies: ["StoreScopeCore", "StoreScopeUI"], swiftSettings: strictConcurrency),
        .testTarget(name: "StoreScopeCoreTests", dependencies: ["StoreScopeCore"]),
        .testTarget(name: "StoreScopeUITests", dependencies: ["StoreScopeUI", "StoreScopeCore"])
    ]
)
