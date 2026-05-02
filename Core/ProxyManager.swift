import Foundation

class ProxyManager {
    static let shared = ProxyManager()

    struct ProxySettings {
        var httpEnabled: Bool = false
        var httpPort: Int = 0
        var httpsEnabled: Bool = false
        var httpsPort: Int = 0
        var socksEnabled: Bool = false
        var socksPort: Int = 0
    }

    private let networkSetupPath = "/usr/sbin/networksetup"

    /// 获取所有网络服务
    func getNetworkServices() -> [String] {
        guard let output = runCommand(networkSetupPath, arguments: ["-listallnetworkservices"]) else { return [] }
        return output.components(separatedBy: "\n")
            .dropFirst() // 第一行是标题
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }

    /// 启用系统代理
    func enableProxy(socksPort: Int, httpPort: Int) -> Bool {
        let services = getNetworkServices()
        var success = false
        for service in services {
            // HTTP 代理
            let r1 = runCommand(networkSetupPath, arguments: ["-setwebproxy", service, "127.0.0.1", "\(httpPort)"])
            let r2 = runCommand(networkSetupPath, arguments: ["-setsecurewebproxy", service, "127.0.0.1", "\(httpPort)"])
            // SOCKS 代理
            let r3 = runCommand(networkSetupPath, arguments: ["-setsocksfirewallproxy", service, "127.0.0.1", "\(socksPort)"])
            // 启用
            let r4 = runCommand(networkSetupPath, arguments: ["-setwebproxystate", service, "on"])
            let r5 = runCommand(networkSetupPath, arguments: ["-setsecurewebproxystate", service, "on"])
            let r6 = runCommand(networkSetupPath, arguments: ["-setsocksfirewallproxystate", service, "on"])
            if r4 != nil { success = true }
        }
        return success
    }

    /// 禁用系统代理
    func disableProxy() {
        let services = getNetworkServices()
        for service in services {
            _ = runCommand(networkSetupPath, arguments: ["-setwebproxystate", service, "off"])
            _ = runCommand(networkSetupPath, arguments: ["-setsecurewebproxystate", service, "off"])
            _ = runCommand(networkSetupPath, arguments: ["-setsocksfirewallproxystate", service, "off"])
        }
    }

    /// 获取当前代理设置
    func getCurrentProxySettings() -> ProxySettings {
        var settings = ProxySettings()
        guard let services = getNetworkServices().first else { return settings }

        if let output = runCommand(networkSetupPath, arguments: ["-getwebproxy", services]) {
            settings.httpEnabled = output.contains("Enabled: Yes")
            if let portLine = output.components(separatedBy: "\n").first(where: { $0.contains("Port:") }) {
                settings.httpPort = Int(portLine.replacingOccurrences(of: "Port:", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        if let output = runCommand(networkSetupPath, arguments: ["-getsocksfirewallproxy", services]) {
            settings.socksEnabled = output.contains("Enabled: Yes")
            if let portLine = output.components(separatedBy: "\n").first(where: { $0.contains("Port:") }) {
                settings.socksPort = Int(portLine.replacingOccurrences(of: "Port:", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        return settings
    }

    // MARK: - Private

    @discardableResult
    private func runCommand(_ command: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
