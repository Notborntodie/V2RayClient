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
    private let logFile: URL

    init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/V2RayClient")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        logFile = logsDir.appendingPathComponent("proxy.log")
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fh = try? FileHandle(forWritingTo: logFile) {
                    _ = try? fh.seekToEnd()
                    fh.write(data)
                    try? fh.close()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    // MARK: - Network Services

    func getNetworkServices() -> [String] {
        guard let output = runCommand(networkSetupPath, arguments: ["-listallnetworkservices"]) else { return [] }
        return output.components(separatedBy: "\n")
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }

    // MARK: - Enable / Disable

    @discardableResult
    func enableProxy(socksPort: Int, httpPort: Int) -> (Bool, String?) {
        let services = getNetworkServices()
        guard !services.isEmpty else {
            log("ERROR: no network services found")
            return (false, "未找到网络服务")
        }
        log("Found services: \(services)")

        var lines = ["#!/bin/bash"]
        for service in services {
            let s = shellQuote(service)
            // 每个命令末尾加 || true，避免某个失败中断后续服务
            lines.append("\(networkSetupPath) -setwebproxy \(s) 127.0.0.1 \(httpPort) || true")
            lines.append("\(networkSetupPath) -setwebproxystate \(s) on || true")
            lines.append("\(networkSetupPath) -setsecurewebproxy \(s) 127.0.0.1 \(httpPort) || true")
            lines.append("\(networkSetupPath) -setsecurewebproxystate \(s) on || true")
            lines.append("\(networkSetupPath) -setsocksfirewallproxy \(s) 127.0.0.1 \(socksPort) || true")
            lines.append("\(networkSetupPath) -setsocksfirewallproxystate \(s) on || true")
        }
        let scriptContent = lines.joined(separator: "\n")

        return executeScript(content: scriptContent, description: "启用系统代理")
    }

    @discardableResult
    func disableProxy() -> (Bool, String?) {
        let services = getNetworkServices()
        guard !services.isEmpty else {
            log("ERROR: no network services found")
            return (false, "未找到网络服务")
        }

        var lines = ["#!/bin/bash"]
        for service in services {
            let s = shellQuote(service)
            lines.append("\(networkSetupPath) -setwebproxystate \(s) off || true")
            lines.append("\(networkSetupPath) -setsecurewebproxystate \(s) off || true")
            lines.append("\(networkSetupPath) -setsocksfirewallproxystate \(s) off || true")
        }
        let scriptContent = lines.joined(separator: "\n")

        return executeScript(content: scriptContent, description: "禁用系统代理")
    }

    // MARK: - Current Settings

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

    // MARK: - Script Execution

    private func executeScript(content: String, description: String) -> (Bool, String?) {
        log("--- \(description) ---")
        log("Script content:\n\(content)")

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("v2ray_proxy_\(UUID().uuidString).sh")

        do {
            try content.write(to: tempFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempFile.path)
        } catch {
            log("ERROR writing temp script: \(error)")
            return (false, "写入临时脚本失败: \(error.localizedDescription)")
        }

        // 1. 先尝试直接执行（完整路径 /bin/bash）
        log("Attempting direct execution...")
        let direct = runCommandWithResult("/bin/bash", arguments: [tempFile.path])
        log("Direct result: success=\(direct.success), error=\(direct.error ?? "nil")")
        if direct.success {
            cleanup(tempFile)
            return (true, nil)
        }

        // 2. 直接失败，通过 AppleScript 请求管理员权限
        log("Direct failed, attempting AppleScript with privileges...")
        let appleScript = """
        do shell script "/bin/bash '\(escapeForAppleScript(tempFile.path))'" with administrator privileges
        """
        let privileged = runCommandWithResult("/usr/bin/osascript", arguments: ["-e", appleScript])
        log("AppleScript result: success=\(privileged.success), error=\(privileged.error ?? "nil")")
        cleanup(tempFile)

        if privileged.success {
            return (true, nil)
        }

        // 分析错误，给出具体提示
        let errLower = (privileged.error ?? "").lowercased()
        if errLower.contains("user canceled") || errLower.contains("-128") {
            return (false, "已取消管理员认证。如需设置系统代理，请点击连接并输入密码。")
        }
        if errLower.contains("not allowed") || errLower.contains("privilege") {
            return (false, "系统拒绝授予管理员权限。请检查：系统设置 → 隐私与安全性 → 自动化，允许 V2RayClient 控制 System Events。")
        }

        return (false, "\(description)失败。错误: \(privileged.error ?? "未知错误")")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Helpers

    /// Shell-safe single-quote quoting: foo'bar -> 'foo'\''bar'
    private func shellQuote(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    /// AppleScript double-quote escaping
    private func escapeForAppleScript(_ s: String) -> String {
        return s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Run a command and return its output string
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

    /// Run a command and return (success, errorMessage)
    private func runCommandWithResult(_ command: String, arguments: [String]) -> (success: Bool, error: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return (true, nil)
            } else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (false, errMsg ?? "exit code \(process.terminationStatus)")
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
