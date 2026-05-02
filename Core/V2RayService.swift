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
    }

    func stop() {
        if let process = process, process.isRunning {
            process.terminate()
            self.process = nil
        }
        isRunning = false
        currentServer = nil

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
