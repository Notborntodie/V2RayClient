import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var socksPort: Int = ConfigManager.shared.socksPort
    @Published var httpPort: Int = ConfigManager.shared.httpPort
    @Published var logLevel: String = ConfigManager.shared.logLevel
    @Published var autoStartAtLogin: Bool = ConfigManager.shared.autoStartAtLogin
    @Published var autoUpdateSubscriptions: Bool = ConfigManager.shared.autoUpdateSubscriptions

    // 直接引用 ConfigManager.shared.proxyMode，不维护本地副本
    var proxyMode: ConfigManager.ProxyMode {
        get { ConfigManager.shared.proxyMode }
        set { ConfigManager.shared.proxyMode = newValue }
    }

    let configManager = ConfigManager.shared

    let logLevels = ["debug", "info", "warning", "error", "none"]

    func save() {
        configManager.socksPort = socksPort
        configManager.httpPort = httpPort
        configManager.logLevel = logLevel
        configManager.autoStartAtLogin = autoStartAtLogin
        configManager.autoUpdateSubscriptions = autoUpdateSubscriptions
        configManager.save()
    }

    func importConfig(from path: String) -> ServerNode? {
        try? configManager.importFromConfig(at: path)
    }
}
