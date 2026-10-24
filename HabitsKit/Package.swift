// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HabitsKit",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "HabitsKit", targets: ["HabitsKit"])],
    targets: [
        .target(name: "HabitsKit"),
        .testTarget(name: "HabitsKitTests", dependencies: ["HabitsKit"]),
    ]
)
