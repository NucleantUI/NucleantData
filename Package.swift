// swift-tools-version: 6.3

import PackageDescription

// Vein's SQLite models, live in NucleantUI views. `import NucleantData`
// brings all of Vein — `@Model`, `ModelContainer`, predicates, migrations —
// and adds what a view needs to show them: `@Query`, the model container in
// the environment, and `VeinContainer`, which migrates before its content
// is shown.
let package = Package(
    name: "NucleantData",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "NucleantData",
            targets: ["NucleantData"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/NucleantUI/NucleantUI", .upToNextMinor(from: "0.3.0")),
        .package(url: "https://github.com/amethystsoft/vein", .upToNextMinor(from: "1.3.0")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.9.1")),
    ],
    targets: [
        .target(
            name: "NucleantData",
            dependencies: [
                .product(name: "VeinCore", package: "vein"),
                .product(name: "NucleantUI", package: "NucleantUI"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "NucleantDataTests",
            dependencies: [
                "NucleantData",
                .product(name: "NucleantUI", package: "NucleantUI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
