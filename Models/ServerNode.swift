import Foundation

struct ServerNode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var address: String
    var port: Int
    var protocolType: ProtocolType
    var uuid: String
    var alterId: Int
    var security: String
    var networkType: NetworkType
    var path: String = ""
    var host: String = ""
    var tlsEnabled: Bool = false
    var sni: String = ""
    var groupName: String = "Default"
    var latency: TimeInterval? = nil
    var totalUpload: Int64 = 0
    var totalDownload: Int64 = 0

    enum ProtocolType: String, Codable, CaseIterable {
        case vmess = "vmess"
        case vless = "vless"
        case shadowsocks = "shadowsocks"
        case trojan = "trojan"
        case socks = "socks"
    }

    enum NetworkType: String, Codable, CaseIterable {
        case tcp = "tcp"
        case kcp = "kcp"
        case ws = "ws"
        case http2 = "h2"
        case quic = "quic"
        case grpc = "grpc"
    }

    init(id: UUID = UUID(), name: String = "", address: String = "", port: Int = 0,
         protocolType: ProtocolType = .vmess, uuid: String = "", alterId: Int = 0,
         security: String = "auto", networkType: NetworkType = .tcp, groupName: String = "Default") {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.protocolType = protocolType
        self.uuid = uuid
        self.alterId = alterId
        self.security = security
        self.networkType = networkType
        self.groupName = groupName
    }

    /// 通用解析入口：自动识别 vmess:// / ss:// / trojan:// 等
    static func from(link: String, groupName: String = "Default") -> ServerNode? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("vmess://") {
            return from(vmessLink: trimmed, groupName: groupName)
        } else if trimmed.hasPrefix("ss://") {
            return from(ssLink: trimmed, groupName: groupName)
        } else if trimmed.hasPrefix("trojan://") {
            return from(trojanLink: trimmed, groupName: groupName)
        }
        return nil
    }

    /// 从 VMess 链接解析节点
    static func from(vmessLink: String, groupName: String = "Default") -> ServerNode? {
        guard vmessLink.hasPrefix("vmess://") else { return nil }
        let base64String = String(vmessLink.dropFirst(8))
        let padded = base64String.padding(toLength: ((base64String.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        guard let jsonData = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let ps = json["ps"] as? String,
              let add = json["add"] as? String else {
            return nil
        }

        // port 可能是 String 或 Int
        let port: Int
        if let portStr = json["port"] as? String {
            port = Int(portStr) ?? 0
        } else if let portInt = json["port"] as? Int {
            port = portInt
        } else {
            port = 0
        }

        // aid 可能是 String 或 Int
        let aid: Int
        if let aidStr = json["aid"] as? String {
            aid = Int(aidStr) ?? 0
        } else if let aidInt = json["aid"] as? Int {
            aid = aidInt
        } else {
            aid = 0
        }

        let id = json["id"] as? String ?? ""
        let net = json["net"] as? String ?? "tcp"
        let networkType = NetworkType(rawValue: net) ?? .tcp

        var node = ServerNode(
            name: ps, address: add, port: port, protocolType: .vmess,
            uuid: id, alterId: aid,
            security: json["scy"] as? String ?? "auto",
            networkType: networkType, groupName: groupName
        )
        node.path = json["path"] as? String ?? ""
        node.host = json["host"] as? String ?? ""
        node.tlsEnabled = (json["tls"] as? String) == "tls"
        node.sni = json["sni"] as? String ?? ""
        return node
    }

    /// 从 Shadowsocks 链接解析: ss://base64(method:password)@host:port#name
    static func from(ssLink: String, groupName: String = "Default") -> ServerNode? {
        guard ssLink.hasPrefix("ss://") else { return nil }
        let body = String(ssLink.dropFirst(5))

        // 解析 #name
        var name = ""
        var mainPart = body
        if let hashIdx = body.lastIndex(of: "#") {
            name = String(body[hashIdx...].dropFirst())
            name = name.removingPercentEncoding ?? name
            mainPart = String(body[..<hashIdx])
        }

        // 格式1: base64(method:password)@host:port
        // 格式2: base64(method:password@host:port)
        if let atIdx = mainPart.firstIndex(of: "@") {
            // SIP002 格式
            let encodedPart = String(mainPart[..<atIdx])
            let serverPart = String(mainPart[atIdx...].dropFirst())

            let padded = encodedPart.padding(toLength: ((encodedPart.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            guard let decoded = Data(base64Encoded: padded),
                  let methodPassword = String(data: decoded, encoding: .utf8) else {
                return nil
            }

            let colonIdx = methodPassword.firstIndex(of: ":") ?? methodPassword.startIndex
            let method = String(methodPassword[..<colonIdx])
            let password = String(methodPassword[colonIdx...].dropFirst())

            // 解析 host:port
            let serverParts = serverPart.split(separator: ":", omittingEmptySubsequences: false)
            guard serverParts.count >= 2,
                  let port = Int(serverParts.last ?? "") else {
                return nil
            }
            let host = serverParts.dropLast().joined(separator: ":")

            return ServerNode(
                name: name.isEmpty ? "\(host):\(port)" : name,
                address: host,
                port: port,
                protocolType: .shadowsocks,
                uuid: password,
                security: method,
                groupName: groupName
            )
        } else {
            // 全 base64 格式: base64(method:password@host:port)
            let padded = mainPart.padding(toLength: ((mainPart.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            guard let decoded = Data(base64Encoded: padded),
                  let full = String(data: decoded, encoding: .utf8) else {
                return nil
            }
            let colonIdx = full.firstIndex(of: ":") ?? full.startIndex
            let method = String(full[..<colonIdx])
            let rest = String(full[colonIdx...].dropFirst())

            let atIdx = rest.firstIndex(of: "@") ?? rest.startIndex
            let password = String(rest[..<atIdx])
            let serverPart = String(rest[atIdx...].dropFirst())

            let serverParts = serverPart.split(separator: ":", omittingEmptySubsequences: false)
            guard serverParts.count >= 2, let port = Int(serverParts.last ?? "") else {
                return nil
            }
            let host = serverParts.dropLast().joined(separator: ":")

            return ServerNode(
                name: name.isEmpty ? "\(host):\(port)" : name,
                address: host,
                port: port,
                protocolType: .shadowsocks,
                uuid: password,
                security: method,
                groupName: groupName
            )
        }
    }

    /// 从 Trojan 链接解析: trojan://password@host:port?sni=xxx#name
    static func from(trojanLink: String, groupName: String = "Default") -> ServerNode? {
        guard trojanLink.hasPrefix("trojan://") else { return nil }
        let body = String(trojanLink.dropFirst(9))

        var name = ""
        var mainPart = body
        if let hashIdx = body.lastIndex(of: "#") {
            name = String(body[hashIdx...].dropFirst())
            name = name.removingPercentEncoding ?? name
            mainPart = String(body[..<hashIdx])
        }

        // 解析 query params
        var sni = ""
        if let queryIdx = mainPart.firstIndex(of: "?") {
            let queryString = String(mainPart[queryIdx...].dropFirst())
            mainPart = String(mainPart[..<queryIdx])
            for param in queryString.split(separator: "&") {
                let kv = param.split(separator: "=", maxSplits: 1)
                if kv.count == 2 && kv[0] == "sni" {
                    sni = String(kv[1])
                }
            }
        }

        guard let atIdx = mainPart.firstIndex(of: "@") else { return nil }
        let password = String(mainPart[..<atIdx])
        let serverPart = String(mainPart[atIdx...].dropFirst())

        let serverParts = serverPart.split(separator: ":", omittingEmptySubsequences: false)
        guard serverParts.count >= 2, let port = Int(serverParts.last ?? "") else {
            return nil
        }
        let host = serverParts.dropLast().joined(separator: ":")

        var node = ServerNode(
            name: name.isEmpty ? "\(host):\(port)" : name,
            address: host,
            port: port,
            protocolType: .trojan,
            uuid: password,
            groupName: groupName
        )
        node.tlsEnabled = true
        node.sni = sni
        return node
    }

    /// 生成 VMess 链接
    func toVMessLink() -> String {
        let jsonDict: [String: Any] = [
            "v": "2", "ps": name, "add": address, "port": port,
            "id": uuid, "aid": alterId, "net": networkType.rawValue,
            "type": "none", "host": host, "path": path,
            "tls": tlsEnabled ? "tls" : ""
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let base64 = jsonString.data(using: .utf8)?.base64EncodedString() else {
            return ""
        }
        return "vmess://\(base64)"
    }

    var latencyText: String {
        guard let latency = latency else { return "未测试" }
        if latency < 0 { return "超时" }
        return "\(Int(latency * 1000)) ms"
    }
}

struct ServerGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var isEnabled: Bool = true

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
    }
}
