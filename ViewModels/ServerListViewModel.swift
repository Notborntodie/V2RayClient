import Foundation
import Combine

class ServerListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedGroup = "All"
    @Published var sortOption: SortOption = .name
    @Published var isTestingLatency = false

    let configManager = ConfigManager.shared

    enum SortOption: String, CaseIterable {
        case name = "名称"
        case latency = "延迟"
        case group = "分组"

        static let allCases: [SortOption] = [.name, .latency, .group]
    }

    /// 筛选后的节点列表
    var filteredNodes: [ServerNode] {
        var result = configManager.nodes

        // 分组筛选
        if selectedGroup != "All" {
            result = result.filter { $0.groupName == selectedGroup }
        }

        // 搜索
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.address.contains(searchText)
            }
        }

        // 排序
        switch sortOption {
        case .name:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .latency:
            result.sort { ($0.latency ?? .infinity) < ($1.latency ?? .infinity) }
        case .group:
            result.sort { $0.groupName < $1.groupName }
        }

        return result
    }

    /// 所有分组名称
    var groupNames: [String] {
        ["All"] + configManager.groups.map(\.name)
    }

    /// 测试所有可见节点延迟
    func testLatency(for nodes: [ServerNode]) async {
        isTestingLatency = true
        let service = V2RayService()
        for node in nodes {
            let latency = await service.testLatency(for: node)
            DispatchQueue.main.async {
                if let idx = self.configManager.nodes.firstIndex(where: { $0.id == node.id }) {
                    self.configManager.nodes[idx].latency = latency
                }
            }
        }
        DispatchQueue.main.async {
            self.configManager.save()
            self.isTestingLatency = false
        }
    }

    /// 删除节点
    func deleteNode(_ node: ServerNode) {
        configManager.removeNode(id: node.id)
    }
}
