import Foundation
import Combine

class SubscriptionManager: ObservableObject {
    private let configManager = ConfigManager.shared
    private var updateTimers: [UUID: Timer] = [:]

    /// 更新单个订阅
    func updateSubscription(_ subscription: Subscription) async throws -> [ServerNode] {
        let content = try await configManager.fetchSubscription(url: subscription.url)
        let nodes = configManager.parseSubscriptionContent(content, groupName: subscription.name)

        var updated = subscription
        updated.lastUpdateDate = Date()
        updated.nodeCount = nodes.count
        configManager.updateSubscription(updated)

        // 更新节点列表：删除旧的同组节点，添加新节点
        configManager.nodes.removeAll { $0.groupName == subscription.name }
        for node in nodes {
            configManager.addNode(node)
        }

        return nodes
    }

    /// 更新所有订阅
    func updateAllSubscriptions() async {
        for sub in configManager.subscriptions where sub.isEnabled && sub.needsUpdate {
            _ = try? await updateSubscription(sub)
        }
    }

    /// 启动定时更新
    func startAutoUpdate() {
        stopAutoUpdate()
        for sub in configManager.subscriptions where sub.autoUpdate {
            let timer = Timer.scheduledTimer(withTimeInterval: sub.updateInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task {
                    _ = try? await self.updateSubscription(sub)
                }
            }
            updateTimers[sub.id] = timer
        }
    }

    /// 停止定时更新
    func stopAutoUpdate() {
        for (_, timer) in updateTimers {
            timer.invalidate()
        }
        updateTimers.removeAll()
    }
}
