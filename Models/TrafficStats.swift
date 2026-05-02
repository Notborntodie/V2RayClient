import Foundation

struct TrafficStats: Codable {
    var uploadSpeed: Int64 = 0       // bytes/s
    var downloadSpeed: Int64 = 0     // bytes/s
    var totalUpload: Int64 = 0       // bytes
    var totalDownload: Int64 = 0     // bytes
    var connectionCount: Int = 0

    var uploadSpeedText: String {
        ByteCountFormatter.string(fromByteCount: uploadSpeed, countStyle: .binary) + "/s"
    }

    var downloadSpeedText: String {
        ByteCountFormatter.string(fromByteCount: downloadSpeed, countStyle: .binary) + "/s"
    }

    var totalUploadText: String {
        ByteCountFormatter.string(fromByteCount: totalUpload, countStyle: .binary)
    }

    var totalDownloadText: String {
        ByteCountFormatter.string(fromByteCount: totalDownload, countStyle: .binary)
    }

    var totalText: String {
        ByteCountFormatter.string(fromByteCount: totalUpload + totalDownload, countStyle: .binary)
    }

    var speedText: String {
        let totalSpeed = uploadSpeed + downloadSpeed
        if totalSpeed == 0 { return "0 B/s" }
        return ByteCountFormatter.string(fromByteCount: totalSpeed, countStyle: .binary) + "/s"
    }

    mutating func reset() {
        uploadSpeed = 0
        downloadSpeed = 0
        totalUpload = 0
        totalDownload = 0
        connectionCount = 0
    }
}
