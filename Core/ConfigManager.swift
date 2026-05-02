import Foundation
import Combine

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published var nodes: [ServerNode] = []
    @Published var subscriptions: [Subscription] = []
    @Published var groups: [ServerGroup] = [ServerGroup(name: "Default")]
    @Published var socksPort: Int = 10808
    @Published var httpPort: Int = 10809
    @Published var logLevel: String = "warning"
    @Published var autoStartAtLogin: Bool = false
    @Published var autoUpdateSubscriptions: Bool = true

    private let saveURL: URL
    private let nodesKey = "saved_nodes"
    private let subsKey = "saved_subscriptions"
    private let groupsKey = "saved_groups"
    private let settingsKey = "app_settings"

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("V2RayClient", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.saveURL = dir
        load()
    }

    // MARK: - Nodes

    func addNode(_ node: ServerNode) {
        if !groups.contains(where: { $0.name == node.groupName }) {
            groups.append(ServerGroup(name: node.groupName))
        }
        nodes.append(node)
        save()
    }

    func removeNode(id: UUID) {
        nodes.removeAll { $0.id == id }
        save()
    }

    func updateNode(_ node: ServerNode) {
        if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[idx] = node
            save()
        }
    }

    func nodesForGroup(_ groupName: String) -> [ServerNode] {
        nodes.filter { $0.groupName == groupName }
    }

    // MARK: - Subscriptions

    func addSubscription(_ sub: Subscription) {
        subscriptions.append(sub)
        save()
    }

    func removeSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        save()
    }

    func updateSubscription(_ sub: Subscription) {
        if let idx = subscriptions.firstIndex(where: { $0.id == sub.id }) {
            subscriptions[idx] = sub
            save()
        }
    }

    // MARK: - Import from subscription

    /// 解析订阅链接内容（Base64 编码的节点列表）
    func parseSubscriptionContent(_ content: String, groupName: String) -> [ServerNode] {
        // Base64 解码
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let padded = cleaned.padding(toLength: ((cleaned.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        guard let data = Data(base64Encoded: padded),
              let decoded = String(data: data, encoding: .utf8) else {
            // 尝试直接按行解析
            return parseLinks(content, groupName: groupName)
        }
        return parseLinks(decoded, groupName: groupName)
    }

    /// 按行解析节点链接（支持 vmess://, ss://, trojan://）
    func parseLinks(_ text: String, groupName: String) -> [ServerNode] {
        var result: [ServerNode] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let node = ServerNode.from(link: trimmed, groupName: groupName) {
                result.append(node)
            }
        }
        return result
    }

    /// 从 URL 获取订阅内容
    func fetchSubscription(url: String) async throws -> String {
        guard let url = URL(string: url) else {
            throw ConfigError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw ConfigError.invalidResponse
        }
        return content
    }

    // MARK: - Import from config.json

    func importFromConfig(at path: String) throws -> ServerNode? {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let outbounds = json?["outbounds"] as? [[String: Any]],
              let proxy = outbounds.first(where: { $0["tag"] as? String == "proxy" }) else {
            return nil
        }

        let proto = proxy["protocol"] as? String ?? "vmess"
        let streamSettings = proxy["streamSettings"] as? [String: Any]
        let network = streamSettings?["network"] as? String ?? "tcp"

        var node = ServerNode(protocolType: .init(rawValue: proto) ?? .vmess, networkType: .init(rawValue: network) ?? .tcp)

        if let vnext = (proxy["settings"] as? [String: Any])?["vnext"] as? [[String: Any]],
           let first = vnext.first {
            node.address = first["address"] as? String ?? ""
            node.port = first["port"] as? Int ?? 0
            if let user = (first["users"] as? [[String: Any]])?.first {
                node.uuid = user["id"] as? String ?? ""
                node.alterId = user["alterId"] as? Int ?? 0
                node.security = user["security"] as? String ?? "auto"
            }
        }

        node.name = "\(node.address):\(node.port)"
        return node
    }

    // MARK: - Persistence

    func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(nodes) {
            try? data.write(to: saveURL.appendingPathComponent("\(nodesKey).json"))
        }
        if let data = try? encoder.encode(subscriptions) {
            try? data.write(to: saveURL.appendingPathComponent("\(subsKey).json"))
        }
        if let data = try? encoder.encode(groups) {
            try? data.write(to: saveURL.appendingPathComponent("\(groupsKey).json"))
        }
        let settings: [String: Any] = [
            "socksPort": socksPort,
            "httpPort": httpPort,
            "logLevel": logLevel,
            "autoStartAtLogin": autoStartAtLogin,
            "autoUpdateSubscriptions": autoUpdateSubscriptions
        ]
        (settings as NSDictionary).write(to: saveURL.appendingPathComponent("\(settingsKey).plist"), atomically: true)
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: saveURL.appendingPathComponent("\(nodesKey).json")) {
            nodes = (try? decoder.decode([ServerNode].self, from: data)) ?? []
        }
        if let data = try? Data(contentsOf: saveURL.appendingPathComponent("\(subsKey).json")) {
            subscriptions = (try? decoder.decode([Subscription].self, from: data)) ?? []
        }
        if let data = try? Data(contentsOf: saveURL.appendingPathComponent("\(groupsKey).json")) {
            groups = (try? decoder.decode([ServerGroup].self, from: data)) ?? [ServerGroup(name: "Default")]
        }
        if let settings = NSDictionary(contentsOf: saveURL.appendingPathComponent("\(settingsKey).plist")) as? [String: Any] {
            socksPort = settings["socksPort"] as? Int ?? 10808
            httpPort = settings["httpPort"] as? Int ?? 10809
            logLevel = settings["logLevel"] as? String ?? "warning"
            autoStartAtLogin = settings["autoStartAtLogin"] as? Bool ?? false
            autoUpdateSubscriptions = settings["autoUpdateSubscriptions"] as? Bool ?? true
        }
    }

    enum ConfigError: LocalizedError {
        case invalidURL
        case invalidResponse
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的 URL"
            case .invalidResponse: return "无效的响应"
            case .parseError: return "解析错误"
            }
        }
    }
}
