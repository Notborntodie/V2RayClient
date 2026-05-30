import Foundation

class BrewManager {
    static let shared = BrewManager()

    private let useBrew: Bool
    private let plistLabel = "qi.v2ray"
    private let plistPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/LaunchAgents/qi.v2ray.plist"
    }()

    var isBrewed: Bool { useBrew }

    var configPath: String {
        useBrew ? "/opt/homebrew/etc/v2ray/config.json" : NSHomeDirectory() + "/.config/v2ray/config.json"
    }

    init() {
        let brewExists = FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/brew")
        let v2rayBrewed = FileManager.default.fileExists(atPath: "/opt/homebrew/opt/v2ray/homebrew.mxcl.v2ray.plist")
        useBrew = brewExists && v2rayBrewed
    }

    var isServiceRunning: Bool {
        if useBrew {
            return checkBrewService()
        } else {
            return checkLaunchdService()
        }
    }

    func startService() throws {
        if useBrew {
            try runBrew(["services", "start", "v2ray"])
        } else {
            try runLaunchctl("load", plistPath)
        }
    }

    func stopService() throws {
        if useBrew {
            try runBrew(["services", "stop", "v2ray"])
        } else {
            try runLaunchctl("unload", plistPath)
        }
    }

    /// 代理连通性检测
    func checkConnectivity() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                process.arguments = [
                    "-x", "http://127.0.0.1:10809",
                    "-m", "8", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                    "https://www.google.com"
                ]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let code = Int(output) ?? 0
                    continuation.resume(returning: (200...399).contains(code))
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// 设置系统代理
    func enableSystemProxy() -> Bool {
        runProxyScript(enable: true)
    }

    func disableSystemProxy() -> Bool {
        runProxyScript(enable: false)
    }

    // MARK: - Private

    private func checkBrewService() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        process.arguments = ["services", "info", "v2ray", "--json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let service = json.first,
                  let running = service["running"] as? Bool else {
                return false
            }
            return running
        } catch {
            return false
        }
    }

    private func checkLaunchdService() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", plistLabel]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func runBrew(_ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw BrewError.operationFailed
        }
    }

    private func runLaunchctl(_ command: String, _ path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = [command, path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw BrewError.operationFailed
        }
    }

    private var sudoersReady = false
    private static let sudoersFile = "/etc/sudoers.d/v2rayclient"

    private func runProxyScript(enable: Bool) -> Bool {
        if !sudoersReady {
            trySetupSudoers()
        }

        let commands: [[String]]
        if enable {
            commands = [
                ["-setwebproxy", "Wi-Fi", "127.0.0.1", "10809"],
                ["-setwebproxystate", "Wi-Fi", "on"],
                ["-setsecurewebproxy", "Wi-Fi", "127.0.0.1", "10809"],
                ["-setsecurewebproxystate", "Wi-Fi", "on"],
                ["-setsocksfirewallproxy", "Wi-Fi", "127.0.0.1", "10808"],
                ["-setsocksfirewallproxystate", "Wi-Fi", "on"],
            ]
        } else {
            commands = [
                ["-setwebproxystate", "Wi-Fi", "off"],
                ["-setsecurewebproxystate", "Wi-Fi", "off"],
                ["-setsocksfirewallproxystate", "Wi-Fi", "off"],
            ]
        }

        if sudoersReady {
            for args in commands {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                p.arguments = ["-n", "/usr/sbin/networksetup"] + args
                try? p.run()
                p.waitUntilExit()
            }
            return true
        }

        // Fallback: osascript with admin prompt once
        let script = "do shell script \"\(commands.map { "/usr/sbin/networksetup " + $0.joined(separator: " ") }.joined(separator: " && "))\" with administrator privileges"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func trySetupSudoers() {
        let check = Process()
        check.executableURL = URL(fileURLWithPath: "/bin/ls")
        check.arguments = [Self.sudoersFile]
        try? check.run()
        check.waitUntilExit()
        if check.terminationStatus == 0 {
            sudoersReady = true
            return
        }

        // One-time setup: create sudoers entry so future calls don't need password
        let content = "%admin ALL=(ALL) NOPASSWD: /usr/sbin/networksetup"
        let script = """
        do shell script "echo '\(content)' > \(Self.sudoersFile) && /usr/sbin/chown root:wheel \(Self.sudoersFile) && /bin/chmod 440 \(Self.sudoersFile)" with administrator privileges
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try? p.run()
        p.waitUntilExit()
        sudoersReady = p.terminationStatus == 0
    }

    enum BrewError: LocalizedError {
        case operationFailed

        var errorDescription: String? {
            switch self {
            case .operationFailed: return "操作 v2ray 服务失败"
            }
        }
    }
}
