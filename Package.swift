// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenCanCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OpenCanCore", targets: ["OpenCanCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.27.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.8.0"),
    ],
    targets: [
        .target(
            name: "OpenCanCore",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Packages/OpenCanCore/Sources/OpenCanCore"
        ),
        .testTarget(
            name: "OpenCanCoreTests",
            dependencies: ["OpenCanCore"],
            path: "Packages/OpenCanCore/Tests/OpenCanCoreTests"
        ),
    ]
)
