// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CallTranscriber",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CallTranscriber", targets: ["CallTranscriber"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/aeromax/FluidAudio.git", branch: "main"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .executableTarget(
            name: "CallTranscriber",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ],
            path: "CallTranscriber",
            resources: [
                .copy("Resources/Models")
            ]
        )
    ]
)
