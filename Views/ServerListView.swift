import SwiftUI

struct ServerListView: View {
    @StateObject private var viewModel = ServerListViewModel()
    @ObservedObject var mainViewModel: MainViewModel
    @State private var selectedNodeID: UUID?
    @EnvironmentObject var appFont: AppFont

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if viewModel.filteredNodes.isEmpty {
                emptyView
            } else {
                nodeList
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(appFont.caption)
                TextField("搜索节点...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(appFont.caption)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(appFont.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Picker("分组", selection: $viewModel.selectedGroup) {
                ForEach(viewModel.groupNames, id: \.self) { group in
                    Text(group).tag(group)
                }
            }
            .frame(width: 120)
            .labelsHidden()

            Picker("排序", selection: $viewModel.sortOption) {
                ForEach(ServerListViewModel.SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .frame(width: 80)
            .labelsHidden()

            Spacer()

            Button(action: testLatency) {
                if viewModel.isTestingLatency {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                }
            }
            .buttonStyle(.plain)
            .help("测试所有节点延迟")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var nodeList: some View {
        List(viewModel.filteredNodes, selection: $selectedNodeID) { node in
            nodeRow(for: node)
        }
        .listStyle(.inset)
    }

    private func nodeRow(for node: ServerNode) -> some View {
        HStack(spacing: 10) {
            let isCurrent = mainViewModel.selectedNode?.id == node.id
            let isActive = mainViewModel.isConnected && isCurrent

            StatusIndicator(isConnected: isActive, size: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(appFont.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(node.address):\(node.port)")
                        .font(appFont.monoCaption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(node.protocolType.rawValue.uppercased())
                        .font(appFont.monoCaption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                    if !node.groupName.isEmpty && node.groupName != "Default" {
                        Text(node.groupName)
                            .font(appFont.caption2)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            LatencyBadge(latency: node.latency)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(mainViewModel.selectedNode?.id == node.id ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .onTapGesture(count: 2) {
            mainViewModel.selectedNode = node
            mainViewModel.connect(to: node)
        }
        .onTapGesture(count: 1) {
            mainViewModel.selectedNode = node
        }
        .contextMenu { nodeContextMenu(for: node) }
    }

    @ViewBuilder
    private func nodeContextMenu(for node: ServerNode) -> some View {
        Button("连接") {
            mainViewModel.selectedNode = node
            mainViewModel.connect(to: node)
        }
        Button("测试延迟") {
            Task {
                let service = V2RayService()
                let latency = await service.testLatency(for: node)
                if let idx = viewModel.configManager.nodes.firstIndex(where: { $0.id == node.id }) {
                    viewModel.configManager.nodes[idx].latency = latency
                    viewModel.configManager.save()
                }
            }
        }
        Divider()
        Button("复制地址") {
            let link = node.toVMessLink()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(link, forType: .string)
        }
        Button("删除", role: .destructive) {
            viewModel.deleteNode(node)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: appFont.iconLarge, weight: .light))
                .foregroundColor(.secondary)
            Text("没有节点")
                .font(appFont.headline)
            Text("添加订阅或手动导入节点")
                .font(appFont.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func testLatency() {
        Task { await viewModel.testLatency(for: viewModel.filteredNodes) }
    }
}
