// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "V2RayClient",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "V2RayClient", targets: ["V2RayClient"])
    ],
    targets: [
        .executableTarget(
            name: "V2RayClient",
            path: ".",
            exclude: ["Package.swift", "gen_xcodeproj.sh", "build_app.sh", "Info.plist", "dist", "README.md", "setup-lele.sh", "AppIcon.icns"],
            sources: [
                "App/V2RayClientApp.swift",
                "App/AppDelegate.swift",
                "Core/BrewManager.swift",
                "Core/SubscriptionManager.swift",
                "Models/Node.swift",
                "ViewModels/MainViewModel.swift",
                "Views/MainView.swift",
                "Views/ConsoleView.swift"
            ]
        )
    ]
)
