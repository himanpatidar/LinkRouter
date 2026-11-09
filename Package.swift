// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LinkRouter",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LinkRouter", targets: ["LinkRouter"]), .library(name: "LinkRouterCore", targets: ["LinkRouterCore"])],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "LinkRouterCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "LinkRouter", dependencies: ["LinkRouterCore"]),
        .testTarget(name: "LinkRouterCoreTests", dependencies: ["LinkRouterCore"])
    ],
    swiftLanguageModes: [.v5]
)
