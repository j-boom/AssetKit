// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AssetKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AssetKit", targets: ["AssetKit"])
    ],
    dependencies: [
        .package(path: "../CastleMindr/CastleMindrModels"),
        .package(path: "../CMCameraKit")
    ],
    targets: [
        .target(
            name: "AssetKit",
            dependencies: ["CastleMindrModels", "CMCameraKit"]
        )
    ]
)
