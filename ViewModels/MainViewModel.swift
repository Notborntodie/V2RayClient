import Foundation
import Combine

class MainViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var isProxyEnabled: Bool = false
    @Published var connectedSince: Date?
    @Published var selectedNode: ServerNode?
    @Published var lastConnectedNode: ServerNode?  // 记住上次连接的节点
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var trafficStats = TrafficStats()
    @Published var errorMessage: String?

    let v2rayService = V2RayService()
    let configManager = ConfigManager.shared
    let subscriptionManager = SubscriptionManager()

    private var cancellables = Set<AnyCancellable>()

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case disconnecting
        case error(String)

        var text: String {
            switch self {
            case .disconnected: return "未连接"
            case .connecting: return "连接中..."
            case .connected: return "已连接"
            case .disconnecting: return "断开中..."
            case .error(let msg): return "错误: \(msg)"
            }
        }

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    var uptimeText: String {
        guard let since = connectedSince else { return "--" }
        let interval = Date().timeIntervalSince(since)
        let mins = Int(interval) / 60
        let hours = mins / 60
        if hours > 0 { return "\(hours)h \(mins % 60)m" }
        return "\(mins)m \(Int(interval) % 60)s"
    }

    init() {
        v2rayService.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.isConnected = running
                // 不在这里设置 isProxyEnabled，由 connect/disconnect 方法控制
            }
            .store(in: &cancellables)

        v2rayService.$trafficStats
            .receive(on: DispatchQueue.main)
            .assign(to: &$trafficStats)

        v2rayService.$currentServer
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedNode)
    }

    func handleToggle(_ enabled: Bool) {
        if enabled {
            // 优先用上次连接的节点，其次用选中的节点，最后选最低延迟
            let node = lastConnectedNode ?? selectedNode ?? lowestLatencyNode
            guard let node = node else {
                isProxyEnabled = false
                return
            }
            selectedNode = node
            connect(to: node)
        } else {
            disconnect()
        }
    }

    /// 延迟最低的节点（已测速的优先，未测速的兜底）
    private var lowestLatencyNode: ServerNode? {
        let nodes = configManager.nodes
        guard !nodes.isEmpty else { return nil }
        let tested = nodes.filter { $0.latency != nil && $0.latency ?? .infinity > 0 }
        if let best = tested.min(by: { ($0.latency ?? .infinity) < ($1.latency ?? .infinity) }) {
            return best
        }
        return nodes.first
    }

    /// 连接到指定节点
    func connect(to node: ServerNode) {
        connectionStatus = .connecting
        errorMessage = nil

        do {
            try v2rayService.start(
                node: node,
                socksPort: configManager.socksPort,
                httpPort: configManager.httpPort,
                logLevel: configManager.logLevel,
                proxyMode: configManager.proxyMode
            )

            // 设置系统代理（不抛异常）
            let (proxySuccess, proxyError) = ProxyManager.shared.enableProxy(
                socksPort: configManager.socksPort,
                httpPort: configManager.httpPort
            )

            if !proxySuccess {
                errorMessage = proxyError ?? "系统代理设置失败，请手动开启"
            }

            connectionStatus = .connected
            isProxyEnabled = true
            connectedSince = Date()
            lastConnectedNode = node  // 记住连接的节点
        } catch {
            connectionStatus = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            isProxyEnabled = false
        }
    }

    /// 断开连接
    func disconnect() {
        connectionStatus = .disconnecting
        v2rayService.stop()
        ProxyManager.shared.disableProxy()
        connectionStatus = .disconnected
        isProxyEnabled = false
        connectedSince = nil
    }

    /// 切换连接
    func toggleConnection() {
        if connectionStatus.isConnected {
            disconnect()
        } else if let node = selectedNode {
            connect(to: node)
        }
    }

    /// 测试所有节点延迟
    func testAllLatency() async {
        for i in configManager.nodes.indices {
            let latency = await v2rayService.testLatency(for: configManager.nodes[i])
            await MainActor.run {
                self.configManager.nodes[i].latency = latency
            }
        }
        await MainActor.run {
            self.configManager.save()
        }
    }

    /// 更新所有订阅
    func updateAllSubscriptions() async {
        await subscriptionManager.updateAllSubscriptions()
    }
}
