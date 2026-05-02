import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var socksPort: Int = ConfigManager.shared.socksPort
    @Published var httpPort: Int = ConfigManager.shared.httpPort
    @Published var logLevel: String = ConfigManager.shared.logLevel
    @Published var autoStartAtLogin: Bool = ConfigManager.shared.autoStartAtLogin
    @Published var autoUpdateSubscriptions: Bool = ConfigManager.shared.autoUpdateSubscriptions

    let configManager = ConfigManager.shared

    let logLevels = ["debug", "info", "warning", "error", "none"]

    func save() {
        configManager.socksPort = socksPort
        configManager.httpPort = httpPort
        configManager.logLevel = logLevel
        configManager.autoStartAtLogin = autoStartAtLogin
        configManager.autoUpdateSubscriptions = autoUpdateSubscriptions
    }

    func importConfig(from path: String) -> ServerNode? {
        try? configManager.importFromConfig(at: path)
    }
}
