import Foundation

struct Subscription: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool = true
    var lastUpdateDate: Date?
    var autoUpdate: Bool = true
    var updateInterval: TimeInterval = 24 * 3600 // 24 hours
    var nodeCount: Int = 0

    init(id: UUID = UUID(), name: String, url: String, isEnabled: Bool = true,
         autoUpdate: Bool = true, updateInterval: TimeInterval = 24 * 3600) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.autoUpdate = autoUpdate
        self.updateInterval = updateInterval
    }

    var needsUpdate: Bool {
        guard let lastUpdate = lastUpdateDate else { return true }
        return Date().timeIntervalSince(lastUpdate) > updateInterval
    }

    var lastUpdateText: String {
        guard let lastUpdate = lastUpdateDate else { return "从未更新" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastUpdate, relativeTo: Date())
    }
}
