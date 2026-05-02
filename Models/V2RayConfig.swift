import Foundation

/// V2Ray JSON 配置生成器
struct V2RayConfig {
    let node: ServerNode
    let socksPort: Int
    let httpPort: Int
    let logLevel: String

    init(node: ServerNode, socksPort: Int = 10808, httpPort: Int = 10809, logLevel: String = "warning") {
        self.node = node
        self.socksPort = socksPort
        self.httpPort = httpPort
        self.logLevel = logLevel
    }

    /// 生成 V2Ray JSON 配置
    func generate() -> String {
        let config: [String: Any] = [
            "log": ["loglevel": logLevel],
            "inbounds": [
                [
                    "tag": "socks",
                    "port": socksPort,
                    "listen": "127.0.0.1",
                    "protocol": "socks",
                    "settings": ["auth": "noauth", "udp": true]
                ],
                [
                    "tag": "http",
                    "port": httpPort,
                    "listen": "127.0.0.1",
                    "protocol": "http",
                    "settings": ["timeout": 0]
                ]
            ],
            "outbounds": buildOutbounds(),
            "routing": [
                "domainStrategy": "AsIs",
                "rules": [
                    ["type": "field", "ip": ["geoip:private"], "outboundTag": "direct"],
                    ["type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "block"]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        return jsonString
    }

    private func buildOutbounds() -> [[String: Any]] {
        let outbound: [String: Any] = [
            "tag": "proxy",
            "protocol": node.protocolType.rawValue,
            "settings": buildOutboundSettings(),
            "streamSettings": buildStreamSettings()
        ]

        return [
            outbound,
            ["tag": "direct", "protocol": "freedom", "settings": [:]],
            ["tag": "block", "protocol": "blackhole", "settings": [:]]
        ]
    }

    private func buildOutboundSettings() -> [String: Any] {
        switch node.protocolType {
        case .vmess, .vless:
            let user: [String: Any] = [
                "id": node.uuid,
                "alterId": node.alterId,
                "security": node.security
            ]
            return [
                "vnext": [
                    ["address": node.address, "port": node.port, "users": [user]]
                ]
            ]
        case .shadowsocks:
            return [
                "servers": [
                    ["address": node.address, "port": node.port, "password": node.uuid, "method": node.security]
                ]
            ]
        case .trojan:
            return [
                "servers": [
                    ["address": node.address, "port": node.port, "password": node.uuid]
                ]
            ]
        case .socks:
            return [
                "servers": [
                    ["address": node.address, "port": node.port]
                ]
            ]
        }
    }

    private func buildStreamSettings() -> [String: Any] {
        var settings: [String: Any] = ["network": node.networkType.rawValue]

        if node.tlsEnabled {
            var tlsSettings: [String: Any] = ["allowInsecure": true]
            if !node.sni.isEmpty {
                tlsSettings["serverName"] = node.sni
            }
            settings["security"] = "tls"
            settings["tlsSettings"] = tlsSettings
        }

        switch node.networkType {
        case .ws:
            var wsSettings: [String: Any] = [:]
            if !node.path.isEmpty { wsSettings["path"] = node.path }
            if !node.host.isEmpty { wsSettings["headers"] = ["Host": node.host] }
            settings["wsSettings"] = wsSettings
        case .grpc:
            var grpcSettings: [String: Any] = [:]
            if !node.path.isEmpty { grpcSettings["serviceName"] = node.path }
            settings["grpcSettings"] = grpcSettings
        case .http2:
            var h2Settings: [String: Any] = [:]
            if !node.path.isEmpty { h2Settings["path"] = node.path }
            if !node.host.isEmpty { h2Settings["host"] = [node.host] }
            settings["httpSettings"] = h2Settings
        default:
            break
        }

        return settings
    }
}
