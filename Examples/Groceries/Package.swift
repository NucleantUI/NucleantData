// swift-tools-version: 6.3

import PackageDescription

// A standalone app on NucleantData, taken from the enclosing checkout: a
// shopping list kept in a database, every list in it a `@Query`.
let package = Package(
    name: "Groceries",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/NucleantUI/NucleantUI", .upToNextMinor(from: "0.3.0")),
    ],
    targets: [
        .executableTarget(
            name: "Groceries",
            dependencies: [
                .product(name: "NucleantData", package: "NucleantData"),
                .product(name: "NucleantUI", package: "NucleantUI"),
            ]
        ),
    ]
)
