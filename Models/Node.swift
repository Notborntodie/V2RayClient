import Foundation

struct V2RayNode: Identifiable, Codable, Hashable {
    var id = UUID()
    var ps: String
    var add: String
    var port: Int
    var uuid: String
    var aid: Int
    var scy: String
    var net: String
    var type: String
    var host: String
    var path: String
    var tls: String

    var displayName: String {
        !ps.isEmpty ? ps : "\(add):\(port)"
    }

    var protocolName: String {
        var desc = "VMess"
        if !net.isEmpty { desc += " / \(net.uppercased())" }
        if tls == "tls" { desc += " / TLS" }
        return desc
    }
}
