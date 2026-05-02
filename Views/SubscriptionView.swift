import SwiftUI

struct SubscriptionRow: View {
    let sub: Subscription
    let onToggle: (Bool) -> Void
    let onUpdate: () -> Void
    @EnvironmentObject var appFont: AppFont

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sub.name)
                    .font(appFont.body)
                Text(sub.url)
                    .font(appFont.monoCaption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Label("\(sub.nodeCount) 个节点", systemImage: "server.rack")
                    Label("更新于 \(sub.lastUpdateText)", systemImage: "clock")
                }
                .font(appFont.caption2)
                .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { sub.isEnabled }, set: onToggle))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.85)
            Button(action: onUpdate) {
                Image(systemName: "arrow.clockwise")
                    .font(appFont.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .help("更新订阅")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

struct SubscriptionView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @EnvironmentObject var appFont: AppFont
    @State private var showingAddSheet = false
    @State private var newSubName = ""
    @State private var newSubURL = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if configManager.subscriptions.isEmpty {
                emptyView
            } else {
                subscriptionList
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addSubscriptionSheet
        }
        .alert("错误", isPresented: .constant(errorMessage != nil)) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var toolbar: some View {
        HStack {
            SectionHeader(title: "订阅管理")
            Spacer()
            Button(action: { showingAddSheet = true }) {
                Label("添加", systemImage: "plus")
                    .font(appFont.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button(action: updateAll) {
                if isUpdating {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Label("更新全部", systemImage: "arrow.clockwise")
                        .font(appFont.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isUpdating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var subscriptionList: some View {
        List {
            ForEach(configManager.subscriptions) { sub in
                SubscriptionRow(
                    sub: sub,
                    onToggle: { enabled in
                        if let idx = configManager.subscriptions.firstIndex(where: { $0.id == sub.id }) {
                            configManager.subscriptions[idx].isEnabled = enabled
                            configManager.save()
                        }
                    },
                    onUpdate: { updateSubscription(sub) }
                )
                .contextMenu {
                    Button("更新") { updateSubscription(sub) }
                    Button("复制链接") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(sub.url, forType: .string)
                    }
                    Divider()
                    Button("删除", role: .destructive) {
                        configManager.removeSubscription(id: sub.id)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: appFont.iconLarge, weight: .light))
                .foregroundColor(.secondary)
            Text("没有订阅")
                .font(appFont.headline)
            Text("点击 + 添加订阅链接")
                .font(appFont.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addSubscriptionSheet: some View {
        VStack(spacing: 20) {
            Text("添加订阅")
                .font(appFont.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("名称").font(appFont.caption).foregroundColor(.secondary)
                TextField("例如: JMS", text: $newSubName)
                    .textFieldStyle(.roundedBorder)
                    .font(appFont.body)
                Text("订阅链接").font(appFont.caption).foregroundColor(.secondary)
                TextField("https://...", text: $newSubURL)
                    .textFieldStyle(.roundedBorder)
                    .font(appFont.body)
            }
            .frame(width: 380)
            HStack {
                Button("取消") { showingAddSheet = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("添加并更新") { addSubscription() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newSubName.isEmpty || newSubURL.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func addSubscription() {
        let sub = Subscription(name: newSubName, url: newSubURL)
        configManager.addSubscription(sub)
        newSubName = ""
        newSubURL = ""
        showingAddSheet = false
        updateSubscription(sub)
    }

    private func updateSubscription(_ sub: Subscription) {
        isUpdating = true
        Task {
            let manager = SubscriptionManager()
            _ = try? await manager.updateSubscription(sub)
            isUpdating = false
        }
    }

    private func updateAll() {
        isUpdating = true
        Task {
            let manager = SubscriptionManager()
            await manager.updateAllSubscriptions()
            isUpdating = false
        }
    }
}
