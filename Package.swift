// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ODTAltyazici",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ODTAltyazici", targets: ["ODTAltyazici"])
    ],
    targets: [
        .executableTarget(
            name: "ODTAltyazici",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
