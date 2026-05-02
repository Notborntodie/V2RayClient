import Foundation
import Combine
import Network

class V2RayService: ObservableObject {
    @Published var isRunning = false
    @Published var currentServer: ServerNode?
    @Published var logs: [String] = []
    @Published var trafficStats = TrafficStats()

    private var process: Process?
    private var logPipe: Pipe?
    private var configPath: String?
    private let maxLogLines = 500
    private var trafficTimer: Timer?
    private var lastUpload: Int64 = 0
    private var lastDownload: Int64 = 0

    var v2rayBinaryPath: String {
        let bundlePath = Bundle.main.bundlePath + "/Contents/Resources/v2ray"
        if FileManager.default.fileExists(atPath: bundlePath) {
            return bundlePath
        }
        let devPath = (Bundle.main.bundlePath as NSString).deletingLastPathComponent + "/v2ray-core/v2ray"
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }
        return "/usr/local/bin/v2ray"
    }

    func start(node: ServerNode, socksPort: Int = 10808, httpPort: Int = 10809, logLevel: String = "warning") throws {
        stop()

        let config = V2RayConfig(node: node, socksPort: socksPort, httpPort: httpPort, logLevel: logLevel)
        let configString = config.generate()

        let tempDir = FileManager.default.temporaryDirectory
        let configFile = tempDir.appendingPathComponent("v2ray_config_\(UUID().uuidString).json")
        try configString.write(to: configFile, atomically: true, encoding: .utf8)
        self.configPath = configFile.path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: v2rayBinaryPath)
        process.arguments = ["run", "-c", configFile.path]
        process.currentDirectoryURL = tempDir

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        self.logPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                self?.logs.append(contentsOf: lines)
                if let self = self, self.logs.count > self.maxLogLines {
                    self.logs.removeFirst(self.logs.count - self.maxLogLines)
                }
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.currentServer = nil
            }
        }

        try process.run()
        self.process = process
        self.currentServer = node
        self.isRunning = true
        startTrafficPolling()
    }

    func stop() {
        stopTrafficPolling()
        if let process = process, process.isRunning {
            process.terminate()
            self.process = nil
        }
        isRunning = false
        currentServer = nil
        trafficStats.reset()
        lastUpload = 0
        lastDownload = 0

        if let path = configPath {
            try? FileManager.default.removeItem(atPath: path)
            self.configPath = nil
        }
    }

    func testLatency(for node: ServerNode) async -> TimeInterval {
        let startTime = Date()
        do {
            try await withTimeout(seconds: 5) {
                try await self.tcpConnect(host: node.address, port: node.port)
            }
            return Date().timeIntervalSince(startTime)
        } catch {
            return -1
        }
    }

    // MARK: - Traffic Polling

    private func startTrafficPolling() {
        trafficStats.reset()
        lastUpload = 0
        lastDownload = 0
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.queryTraffic()
        }
    }

    private func stopTrafficPolling() {
        trafficTimer?.invalidate()
        trafficTimer = nil
    }

    private func queryTraffic() {
        guard isRunning else { return }
        DispatchQueue.global().async { [weak self] in
            self?.queryStatsViaGRPC()
        }
    }

    private func pollNetworkStats() {
        // Use v2ray stats API: query all user traffic
        // v2ray 5.x supports REST-like stats query
        // For v2ray 4.x, we need gRPC - use a simpler approach

        // Approach: measure bytes on local proxy ports via netstat
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "netstat -I lo0 -b 2>/dev/null || echo '0 0'"]

        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        // Fallback: parse v2ray log for traffic data
        // Look for lines containing traffic stats
        var uplink: Int64 = 0
        var downlink: Int64 = 0

        for line in logs.suffix(50) {
            if line.contains("uplink") || line.contains("downloaded") {
                // v2ray sometimes logs: "uplink: xxx bytes, downlink: xxx bytes"
                if let match = line.range(of: #"uplink:\s*(\d+)"#, options: .regularExpression) {
                    let numStr = String(line[match]).replacingOccurrences(of: "uplink:", with: "").trimmingCharacters(in: .whitespaces)
                    uplink = Int64(numStr) ?? 0
                }
                if let match = line.range(of: #"downlink:\s*(\d+)"#, options: .regularExpression) {
                    let numStr = String(line[match]).replacingOccurrences(of: "downlink:", with: "").trimmingCharacters(in: .whitespaces)
                    downlink = Int64(numStr) ?? 0
                }
            }
        }

        // If no log-based stats, use the grpc stats API call
        if uplink == 0 && downlink == 0 {
            queryStatsViaGRPC()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let oldUp = self.lastUpload
            let oldDown = self.lastDownload
            self.trafficStats.totalUpload = uplink
            self.trafficStats.totalDownload = downlink
            self.trafficStats.uploadSpeed = max(0, uplink - oldUp)
            self.trafficStats.downloadSpeed = max(0, downlink - oldDown)
            self.lastUpload = uplink
            self.lastDownload = downlink
        }
    }

    private func queryStatsViaGRPC() {
        // Call v2ray stats gRPC API using the v2ray binary's api command
        let binary = v2rayBinaryPath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary)
        task.arguments = ["api", "statsquery", "-s", "127.0.0.1:15481", "-pattern", ""]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            // Don't wait too long
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if task.isRunning { task.terminate() }
            }
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            var uplink: Int64 = 0
            var downlink: Int64 = 0

            // Parse output like: "stat: <name> >>>> <value>"
            for line in output.components(separatedBy: "\n") {
                if line.contains(">>>") {
                    let parts = line.components(separatedBy: ">>>")
                    guard parts.count == 2 else { continue }
                    let name = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = Int64(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                    if name.contains("uplink") { uplink += value }
                    if name.contains("downlink") { downlink += value }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let oldUp = self.lastUpload
                let oldDown = self.lastDownload
                self.trafficStats.totalUpload = uplink
                self.trafficStats.totalDownload = downlink
                self.trafficStats.uploadSpeed = max(0, uplink - oldUp)
                self.trafficStats.downloadSpeed = max(0, downlink - oldDown)
                self.lastUpload = uplink
                self.lastDownload = downlink
            }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Private

    private func tcpConnect(host: String, port: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let endpointHost = NWEndpoint.Host(host)
            guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                continuation.resume(throwing: V2RayError.processError("Invalid port"))
                return
            }
            let conn = Network.NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    conn.cancel()
                    continuation.resume()
                case .failed(let error):
                    conn.cancel()
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            conn.start(queue: .global())
        }
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw V2RayError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    enum V2RayError: LocalizedError {
        case timeout
        case processError(String)

        var errorDescription: String? {
            switch self {
            case .timeout: return "连接超时"
            case .processError(let msg): return msg
            }
        }
    }
}
