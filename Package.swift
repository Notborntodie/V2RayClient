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
            exclude: ["Package.swift", "gen_xcodeproj.sh", "build_app.sh", "Info.plist", "dist"],
            sources: [
                "App/V2RayClientApp.swift",
                "App/AppDelegate.swift",
                "Core/V2RayService.swift",
                "Core/ConfigManager.swift",
                "Core/SubscriptionManager.swift",
                "Core/ProxyManager.swift",
                "Models/ServerNode.swift",
                "Models/Subscription.swift",
                "Models/V2RayConfig.swift",
                "Models/TrafficStats.swift",
                "ViewModels/MainViewModel.swift",
                "ViewModels/ServerListViewModel.swift",
                "ViewModels/SettingsViewModel.swift",
                "Views/MainView.swift",
                "Views/ServerListView.swift",
                "Views/SubscriptionView.swift",
                "Views/SettingsView.swift",
                "Views/DashboardView.swift",
                "Views/LogView.swift",
                "Views/Components/CommonComponents.swift",
                "Views/Components/StatusCard.swift",
                "Views/Components/ConnectionLogRow.swift",
                "Views/Components/AppFont.swift"
            ]
        )
    ]
)
