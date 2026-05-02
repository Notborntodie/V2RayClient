import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTab: Tab = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject var appFont: AppFont

    enum Tab: String, CaseIterable, Identifiable {
        case dashboard = "概览"
        case servers = "节点"
        case subscriptions = "订阅"
        case logs = "日志"
        case settings = "设置"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.67percent"
            case .servers: return "server.rack"
            case .subscriptions: return "link"
            case .logs: return "doc.text"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            contentArea
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 860, minHeight: 560)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: Binding(
            get: { selectedTab },
            set: { if let t = $0 { selectedTab = t } }
        )) {
            sidebarHeader
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Section("连接") {
                Label("概览", systemImage: "gauge.with.dots.needle.67percent").tag(Tab.dashboard)
                    .font(appFont.body)
                Label("节点", systemImage: "server.rack").tag(Tab.servers)
                    .font(appFont.body)
                Label("订阅", systemImage: "link").tag(Tab.subscriptions)
                    .font(appFont.body)
            }

            Section("工具") {
                Label("日志", systemImage: "doc.text").tag(Tab.logs)
                    .font(appFont.body)
            }

            Section {
                Label("设置", systemImage: "gearshape").tag(Tab.settings)
                    .font(appFont.body)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 200, maxWidth: 220)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: appFont.base(24)))
                    .foregroundColor(.accentColor)
                Text("V2Ray")
                    .font(.system(size: appFont.base(20), weight: .semibold))
            }

            HStack {
                Text("VPN")
                    .font(appFont.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.isProxyEnabled },
                    set: { viewModel.handleToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.regular)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 10, height: 10)
                Text(viewModel.isConnected ? "已连接" : "未连接")
                    .font(appFont.caption)
                    .foregroundColor(viewModel.isConnected ? .green : .secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView(viewModel: viewModel)
                .navigationTitle("概览")
        case .servers:
            ServerListView(mainViewModel: viewModel)
                .navigationTitle("节点")
        case .subscriptions:
            SubscriptionView()
                .navigationTitle("订阅")
        case .logs:
            LogView(viewModel: viewModel)
                .navigationTitle("日志")
        case .settings:
            SettingsView()
                .navigationTitle("设置")
        }
    }
}
