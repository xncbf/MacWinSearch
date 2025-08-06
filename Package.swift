// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MacWinSearch",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "MacWinSearch",
            targets: ["MacWinSearch"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacWinSearch",
            dependencies: [],
            path: "MacWinSearch/Sources"
        )
    ]
)