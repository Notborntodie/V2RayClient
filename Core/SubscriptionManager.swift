import Foundation

class SubscriptionManager {
    static let shared = SubscriptionManager()

    private let defaults = UserDefaults.standard
    private let nodesKey = "saved_nodes"
    private let subscriptionURLKey = "subscription_url"

    var subscriptionURL: String {
        get { defaults.string(forKey: subscriptionURLKey) ?? "" }
        set { defaults.set(newValue, forKey: subscriptionURLKey) }
    }

    // MARK: - Fetch

    func fetchNodes(from urlStr: String) async throws -> [V2RayNode] {
        guard let url = URL(string: urlStr), !urlStr.isEmpty else {
            throw SubError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SubError.fetchFailed
        }

        let content = decodeBase64(text) ?? text
        let nodes = parseVMessLinks(content)

        guard !nodes.isEmpty else {
            throw SubError.parseFailed
        }

        saveNodes(nodes)
        return nodes
    }

    // MARK: - Config Generation

    func writeConfig(for node: V2RayNode, configPath: String) throws {
        let current = readCurrentConfig(configPath: configPath)

        var streamSettings: [String: Any] = ["network": node.net.isEmpty ? "tcp" : node.net]
        if node.net == "ws" {
            var wsSettings: [String: Any] = [:]
            if !node.path.isEmpty { wsSettings["path"] = node.path }
            if !node.host.isEmpty { wsSettings["headers"] = ["Host": node.host] }
            if !wsSettings.isEmpty { streamSettings["wsSettings"] = wsSettings }
        }
        if node.tls == "tls" {
            streamSettings["security"] = "tls"
        }

        let proxyOutbound: [String: Any] = [
            "protocol": "vmess",
            "tag": "proxy",
            "streamSettings": streamSettings,
            "settings": [
                "vnext": [[
                    "address": node.add,
                    "port": node.port,
                    "users": [[
                        "id": node.uuid,
                        "alterId": node.aid,
                        "security": node.scy.isEmpty ? "auto" : node.scy
                    ]]
                ]]
            ]
        ]

        var outbounds = current.outbounds
        if let idx = outbounds.firstIndex(where: { ($0["tag"] as? String) == "proxy" }) {
            outbounds[idx] = proxyOutbound
        } else {
            outbounds.insert(proxyOutbound, at: 0)
        }

        var config: [String: Any] = [:]
        if let log = current.log { config["log"] = log }
        config["outbounds"] = outbounds
        config["inbounds"] = current.inbounds
        if let routing = current.routing { config["routing"] = routing }

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .withoutEscapingSlashes])
        try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }

    // MARK: - Persistence

    func loadNodes() -> [V2RayNode] {
        guard let data = defaults.data(forKey: nodesKey),
              let nodes = try? JSONDecoder().decode([V2RayNode].self, from: data) else {
            return []
        }
        return nodes
    }

    func saveSelectedNodeId(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: "selected_node_id")
    }

    func loadSelectedNodeId() -> UUID? {
        guard let str = defaults.string(forKey: "selected_node_id") else { return nil }
        return UUID(uuidString: str)
    }

    // MARK: - Private

    private func saveNodes(_ nodes: [V2RayNode]) {
        if let data = try? JSONEncoder().encode(nodes) {
            defaults.set(data, forKey: nodesKey)
        }
    }

    private func parseVMessLinks(_ text: String) -> [V2RayNode] {
        text.components(separatedBy: .newlines).compactMap { line in
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.hasPrefix("vmess://") else { return nil }
            return parseSingleVMess(t)
        }
    }

    private func parseSingleVMess(_ link: String) -> V2RayNode? {
        let base64Str = String(link.dropFirst(8))
        guard let jsonStr = decodeBase64(base64Str),
              let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return V2RayNode(
            ps: json["ps"] as? String ?? "",
            add: json["add"] as? String ?? "",
            port: Int(json["port"] as? String ?? "0") ?? 0,
            uuid: json["id"] as? String ?? "",
            aid: (json["aid"] as? Int) ?? Int(json["aid"] as? String ?? "0") ?? 0,
            scy: json["scy"] as? String ?? "auto",
            net: json["net"] as? String ?? "tcp",
            type: json["type"] as? String ?? "none",
            host: json["host"] as? String ?? "",
            path: json["path"] as? String ?? "",
            tls: json["tls"] as? String ?? ""
        )
    }

    private func decodeBase64(_ string: String) -> String? {
        let cleaned = string
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        var encoded = cleaned
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = encoded.count % 4
        if rem > 0 { encoded += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func readCurrentConfig(configPath: String) -> (log: [String: Any]?, outbounds: [[String: Any]], inbounds: [[String: Any]], routing: [String: Any]?) {
        let fallbackInbounds: [[String: Any]] = [
            ["tag": "socks", "listen": "127.0.0.1", "port": 10808, "protocol": "socks",
             "settings": ["udp": true, "auth": "noauth"]],
            ["port": 10809, "listen": "127.0.0.1", "tag": "http", "protocol": "http",
             "settings": ["timeout": 0]]
        ]
        let fallbackRouting: [String: Any] = [
            "domainStrategy": "IPIfNonMatch",
            "rules": [
                ["type": "field", "domain": ["geosite:cn"], "outboundTag": "direct"],
                ["type": "field", "ip": ["geoip:cn", "geoip:private"], "outboundTag": "direct"],
                ["type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "block"]
            ]
        ]

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, [], fallbackInbounds, fallbackRouting)
        }

        return (
            json["log"] as? [String: Any],
            json["outbounds"] as? [[String: Any]] ?? [],
            json["inbounds"] as? [[String: Any]] ?? fallbackInbounds,
            json["routing"] as? [String: Any] ?? fallbackRouting
        )
    }

    enum SubError: LocalizedError {
        case invalidURL, fetchFailed, parseFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "订阅链接无效"
            case .fetchFailed: return "获取订阅失败"
            case .parseFailed: return "解析节点失败"
            }
        }
    }
}
