import Foundation
import Combine
import UserNotifications
import AppKit

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}

class MainViewModel: ObservableObject {
    static let shared = MainViewModel()
    @Published var isRunning = false
    @Published var isChecking = false
    @Published var lastError: String?
    @Published var proxyEnabled = false
    @Published var logEntries: [LogEntry] = []
    @Published var lastLatency: String?

    // Subscription
    @Published var nodes: [V2RayNode] = []
    @Published var selectedNode: V2RayNode?
    @Published var isRefreshing = false
    @Published var nodeCountLabel = ""

    private let brew = BrewManager.shared
    private let sub = SubscriptionManager.shared
    private var healthTimer: Timer?
    private var rotationTimer: Timer?
    private var subscriptionTimer: Timer?
    private var monitorTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    private let failoverThreshold = 3
    private var isSwitchingNode = false

    private init() {
        // Set default subscription URL if not configured
        if sub.subscriptionURL.isEmpty {
            sub.subscriptionURL = "https://jmssub.net/members/getsub.php?service=1364483&id=70041908-6660-4a95-94ee-76c77d277289"
        }

        refreshStatus()
        startHealthCheck()
        log("服务初始化")

        // Restore saved nodes and selected node
        nodes = sub.loadNodes()
        nodeCountLabel = nodes.isEmpty ? "" : "\(nodes.count) 个节点"

        if let savedId = sub.loadSelectedNodeId() {
            selectedNode = nodes.first { $0.id == savedId }
        }
        if selectedNode == nil {
            selectedNode = nodes.first
        }

        // Fetch subscription in background
        Task { await refreshSubscription() }
    }

    // MARK: - Service Control

    func refreshStatus() {
        let wasRunning = isRunning
        isRunning = brew.isServiceRunning
        if isRunning != wasRunning {
            if isRunning { log("服务已运行") }
        }
        if !isRunning {
            proxyEnabled = false
        }
    }

    func toggleService() {
        isChecking = true
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    func toggleProxy() {
        if proxyEnabled {
            _ = brew.disableSystemProxy()
            proxyEnabled = false
            log("系统代理已关闭")
        } else {
            _ = brew.enableSystemProxy()
            proxyEnabled = true
            log("系统代理已开启")
        }
    }

    private func start() {
        lastError = nil
        log("正在启动服务...")
        do {
            try brew.startService()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.refreshStatus()
                self?.isChecking = false
                if self?.isRunning == true {
                    self?.log("服务启动成功")
                    self?.proxyEnabled = true
                    _ = self?.brew.enableSystemProxy()
                    self?.log("系统代理已开启")
                } else {
                    self?.log("服务启动失败")
                }
            }
        } catch {
            lastError = error.localizedDescription
            log("启动失败: \(error.localizedDescription)")
            isChecking = false
        }
    }

    private func stop() {
        log("正在停止服务...")
        do {
            try brew.stopService()
            proxyEnabled = false
            _ = brew.disableSystemProxy()
            log("服务已停止")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.refreshStatus()
                self?.isChecking = false
            }
        } catch {
            lastError = error.localizedDescription
            log("停止失败: \(error.localizedDescription)")
            isChecking = false
        }
    }

    // MARK: - Subscription

    func refreshSubscription() async {
        await MainActor.run {
            isRefreshing = true
            lastError = nil
        }
        log("正在获取订阅...")

        do {
            let fetched = try await sub.fetchNodes(from: sub.subscriptionURL)
            await MainActor.run {
                nodes = fetched
                nodeCountLabel = "\(fetched.count) 个节点"
                log("订阅更新成功，\(fetched.count) 个节点")

                // Restore selection or pick first
                if let savedId = sub.loadSelectedNodeId(),
                   let match = fetched.first(where: { $0.id == savedId }) {
                    selectedNode = match
                } else if selectedNode == nil || !fetched.contains(where: { $0.id == selectedNode?.id }) {
                    selectedNode = fetched.first
                }
                isRefreshing = false
            }
        } catch {
            await MainActor.run {
                log("订阅更新失败: \(error.localizedDescription)")
                lastError = error.localizedDescription
                isRefreshing = false
            }
        }
    }

    func switchToNode(_ node: V2RayNode) {
        guard !isSwitchingNode, node != selectedNode else { return }
        isSwitchingNode = true
        log("切换到节点: \(node.displayName)")
        selectedNode = node
        sub.saveSelectedNodeId(node.id)

        let wasRunning = isRunning

        do {
            try sub.writeConfig(for: node, configPath: brew.configPath)
            log("配置已更新")

            if wasRunning {
                try brew.stopService()
                try brew.startService()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.refreshStatus()
                    self?.isSwitchingNode = false
                    if self?.isRunning == true {
                        self?.log("节点切换成功")
                    } else {
                        self?.log("节点切换失败，服务未启动")
                    }
                }
            } else {
                isSwitchingNode = false
            }
        } catch {
            log("切换节点失败: \(error.localizedDescription)")
            lastError = error.localizedDescription
            isSwitchingNode = false
        }
    }

    // MARK: - Health Check & Rotation

    private func startHealthCheck() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.monitorTask = Task { [weak self] in
                guard let self = self else { return }
                let start = CFAbsoluteTimeGetCurrent()
                let ok = await self.brew.checkConnectivity()
                let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                await MainActor.run {
                    self.lastLatency = ok ? "\(elapsed)ms" : nil
                    if ok {
                        self.consecutiveFailures = 0
                        self.lastError = nil
                    } else {
                        self.consecutiveFailures += 1
                        self.log("连接异常 (\(elapsed)ms)")
                        if self.consecutiveFailures >= 2 {
                            self.lastError = "代理连接异常"
                            self.sendNotification(title: "V2Ray 代理异常", body: "无法通过代理访问外网，请检查服务状态")
                        }
                        if self.consecutiveFailures >= self.failoverThreshold && !self.isSwitchingNode {
                            self.performFailover()
                        }
                    }
                }
            }
        }

        // 每30分钟自动轮换到下一个节点
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.rotateNode()
        }

        // 每6小时刷新一次订阅
        subscriptionTimer = Timer.scheduledTimer(withTimeInterval: 21600, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refreshSubscription() }
        }
    }

    private func rotateNode() {
        guard isSwitchingNode == false, isRunning, nodes.count > 1, let current = selectedNode else { return }
        let currentIndex = nodes.firstIndex { $0.id == current.id } ?? -1
        let nextIndex = (currentIndex + 1) % nodes.count
        let nextNode = nodes[nextIndex]
        guard nextNode.id != current.id else { return }

        isSwitchingNode = true
        log("自动轮换到: \(nextNode.displayName)")
        selectedNode = nextNode
        sub.saveSelectedNodeId(nextNode.id)

        do {
            try sub.writeConfig(for: nextNode, configPath: brew.configPath)
            try brew.stopService()
            try brew.startService()
            consecutiveFailures = 0

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.refreshStatus()
                self?.isSwitchingNode = false
                if self?.isRunning != true {
                    self?.log("轮换后服务未启动，等待下次轮训")
                }
            }
        } catch {
            log("轮换失败: \(error.localizedDescription)")
            isSwitchingNode = false
        }
    }

    private func performFailover() {
        guard !nodes.isEmpty, let current = selectedNode else { return }
        isSwitchingNode = true
        log("正在自动切换节点...")

        // Find next node in rotation
        let currentIndex = nodes.firstIndex { $0.id == current.id } ?? -1
        let nextIndex = (currentIndex + 1) % nodes.count
        let nextNode = nodes[nextIndex]

        guard nextNode.id != current.id else {
            log("无可用节点可切换")
            isSwitchingNode = false
            return
        }

        do {
            try sub.writeConfig(for: nextNode, configPath: brew.configPath)
            selectedNode = nextNode
            sub.saveSelectedNodeId(nextNode.id)
            try brew.stopService()
            try brew.startService()
            consecutiveFailures = 0
            log("自动切换到: \(nextNode.displayName)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                self.refreshStatus()
                self.isSwitchingNode = false
                if !self.isRunning {
                    self.log("切换后服务未运行，尝试下一个节点")
                    // Will trigger another failover on next health check
                }
            }
        } catch {
            log("自动切换失败: \(error.localizedDescription)")
            isSwitchingNode = false
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let entry = LogEntry(timestamp: Date(), message: message)
        DispatchQueue.main.async { [weak self] in
            self?.logEntries.append(entry)
            if (self?.logEntries.count ?? 0) > 100 {
                self?.logEntries.removeFirst((self?.logEntries.count ?? 0) - 100)
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    deinit {
        healthTimer?.invalidate()
        rotationTimer?.invalidate()
        subscriptionTimer?.invalidate()
        monitorTask?.cancel()
    }
}
