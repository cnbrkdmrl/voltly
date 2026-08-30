// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Voltly",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Voltly", targets: ["Voltly"])
    ],
    targets: [
        .target(
            name: "Voltly",
            path: "Sources/Voltly",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("VOLTLY_ENABLE_SWIFTDATA", .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "VoltlyTests",
            dependencies: ["Voltly"],
            path: "Tests/VoltlyTests",
            exclude: [
                "Fixtures"
            ],
            swiftSettings: [
                .define("VOLTLY_ENABLE_SWIFTDATA", .when(platforms: [.iOS]))
            ]
        )
    ]
)
