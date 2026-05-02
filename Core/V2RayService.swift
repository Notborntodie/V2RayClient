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
    private var baselineUpload: Int64 = 0
    private var baselineDownload: Int64 = 0
    private var hasBaseline = false

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

    func start(node: ServerNode, socksPort: Int = 10808, httpPort: Int = 10809, logLevel: String = "warning", proxyMode: ConfigManager.ProxyMode = .rule) throws {
        stop()

        let config = V2RayConfig(node: node, socksPort: socksPort, httpPort: httpPort, logLevel: logLevel, proxyMode: proxyMode)
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
        hasBaseline = false

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
        hasBaseline = false
        hasBaseline = false
        // Record baseline (lo0 bytes before proxy starts)
        if let (ibytes, obytes) = readLo0Stats() {
            baselineUpload = obytes
            baselineDownload = ibytes
            hasBaseline = true
        }
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.queryTraffic()
        }
    }

    private func stopTrafficPolling() {
        trafficTimer?.invalidate()
        trafficTimer = nil
    }

    private func queryTraffic() {
        guard isRunning, hasBaseline else { return }
        guard let (ibytes, obytes) = readLo0Stats() else { return }

        // Proxy download = lo0 input bytes since baseline
        // Proxy upload = lo0 output bytes since baseline
        let download = max(0, ibytes - baselineDownload)
        let upload = max(0, obytes - baselineUpload)

        let oldUp = lastUpload
        let oldDown = lastDownload
        trafficStats.totalUpload = upload
        trafficStats.totalDownload = download
        trafficStats.uploadSpeed = max(0, upload - oldUp)
        trafficStats.downloadSpeed = max(0, download - oldDown)
        lastUpload = upload
        lastDownload = download
    }

    /// Read lo0 (loopback) interface cumulative byte counters via netstat
    private func readLo0Stats() -> (ibytes: Int64, obytes: Int64)? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-c", "netstat -I lo0 -b -n 2>/dev/null | awk 'NR==3 {print $7, $10}'"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = output.split(separator: " ").compactMap { Int64($0) }
        if parts.count >= 2 {
            return (parts[0], parts[1])
        }
        return nil
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
