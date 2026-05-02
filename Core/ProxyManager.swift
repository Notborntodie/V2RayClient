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
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }

    /// 启用系统代理（使用 AppleScript 请求管理员权限）
    func enableProxy(socksPort: Int, httpPort: Int) -> Bool {
        let services = getNetworkServices()
        guard !services.isEmpty else { return false }

        for service in services {
            // HTTP proxy
            let script1 = "do shell script \"networksetup -setwebproxy \\\"\(service)\\\" 127.0.0.1 \(httpPort)\" with administrator privileges"
            let script2 = "do shell script \"networksetup -setwebproxystate \\\"\(service)\\\" on\" with administrator privileges"
            // HTTPS proxy
            let script3 = "do shell script \"networksetup -setsecurewebproxy \\\"\(service)\\\" 127.0.0.1 \(httpPort)\" with administrator privileges"
            let script4 = "do shell script \"networksetup -setsecurewebproxystate \\\"\(service)\\\" on\" with administrator privileges"
            // SOCKS proxy
            let script5 = "do shell script \"networksetup -setsocksfirewallproxy \\\"\(service)\\\" 127.0.0.1 \(socksPort)\" with administrator privileges"
            let script6 = "do shell script \"networksetup -setsocksfirewallproxystate \\\"\(service)\\\" on\" with administrator privileges"

            // 执行所有脚本
            if !runAppleScript(script1) { return false }
            if !runAppleScript(script2) { return false }
            if !runAppleScript(script3) { return false }
            if !runAppleScript(script4) { return false }
            if !runAppleScript(script5) { return false }
            if !runAppleScript(script6) { return false }
        }
        return true
    }

    /// 禁用系统代理
    func disableProxy() -> Bool {
        let services = getNetworkServices()
        guard !services.isEmpty else { return false }

        for service in services {
            let script1 = "do shell script \"networksetup -setwebproxystate \\\"\(service)\\\" off\" with administrator privileges"
            let script2 = "do shell script \"networksetup -setsecurewebproxystate \\\"\(service)\\\" off\" with administrator privileges"
            let script3 = "do shell script \"networksetup -setsocksfirewallproxystate \\\"\(service)\\\" off\" with administrator privileges"

            if !runAppleScript(script1) { return false }
            if !runAppleScript(script2) { return false }
            if !runAppleScript(script3) { return false }
        }
        return true
    }

    /// 获取当前代理设置
    func getCurrentProxySettings() -> ProxySettings {
        var settings = ProxySettings()
        guard let service = getNetworkServices().first else { return settings }

        if let output = runCommand(networkSetupPath, arguments: ["-getwebproxy", service]) {
            settings.httpEnabled = output.contains("Enabled: Yes")
            if let portLine = output.components(separatedBy: "\n").first(where: { $0.contains("Port:") }) {
                settings.httpPort = Int(portLine.replacingOccurrences(of: "Port:", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        if let output = runCommand(networkSetupPath, arguments: ["-getsocksfirewallproxy", service]) {
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

    /// 执行 AppleScript
    private func runAppleScript(_ script: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}