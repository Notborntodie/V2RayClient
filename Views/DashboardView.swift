import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: MainViewModel
    @ObservedObject var configManager = ConfigManager.shared
    @EnvironmentObject var appFont: AppFont
    @State private var connectionLogs: [ConnectionLogEntry] = []
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                connectionHeroCard
                proxyModeCard
                trafficStatsCard
                recentConnections
            }
            .padding(24)
        }
        .onReceive(timer) { _ in refreshLogs() }
        .onAppear { refreshLogs() }
    }

    // MARK: - Hero Connection Card

    private var connectionHeroCard: some View {
        HStack(spacing: 20) {
            // Left: status circle + info
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(viewModel.isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.15), lineWidth: 3)
                        .frame(width: 48, height: 48)
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.gray.opacity(0.4))
                        .frame(width: 16, height: 16)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(viewModel.isConnected ? "已连接" : "未连接")
                            .font(appFont.headline)
                            .foregroundColor(viewModel.isConnected ? .green : .primary)
                        if let node = viewModel.selectedNode {
                            Text("—")
                                .foregroundColor(.secondary)
                            Text(node.name)
                                .font(appFont.headline)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        if let node = viewModel.selectedNode {
                            Text(node.protocolType.rawValue.uppercased())
                                .font(appFont.caption)
                                .foregroundColor(.secondary)
                        }
                        if viewModel.isConnected, let node = viewModel.selectedNode {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(node.latencyText)
                                .font(appFont.caption)
                                .foregroundColor(.secondary)
                        }
                        if viewModel.isConnected {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text("运行 \(viewModel.uptimeText)")
                                .font(appFont.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(appFont.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
            }

            Spacer()

            // Right: large toggle
            Toggle("", isOn: Binding(
                get: { viewModel.isProxyEnabled },
                set: { viewModel.handleToggle($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.large)
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewModel.isConnected ? Color.green.opacity(0.05) : Color.gray.opacity(0.03))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Traffic Stats Card

    private var trafficStatsCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("流量统计")
                    .font(appFont.subheadline)
                    .foregroundColor(.secondary)
                Text(viewModel.trafficStats.totalText)
                    .font(appFont.title2)
                    .monospacedDigit()
                Text("速度 \(viewModel.trafficStats.speedText)")
                    .font(appFont.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Proxy Mode Card

    private var proxyModeCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("代理模式")
                    .font(appFont.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: { switchMode(.rule) }) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .opacity(configManager.proxyMode == .rule ? 1 : 0)
                        Text("规则代理")
                            .font(appFont.body)
                        Text("国内直连")
                            .font(appFont.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(configManager.proxyMode == .rule ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(configManager.proxyMode == .rule ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { switchMode(.global) }) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .opacity(configManager.proxyMode == .global ? 1 : 0)
                        Text("全局代理")
                            .font(appFont.body)
                        Text("全部走代理")
                            .font(appFont.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(configManager.proxyMode == .global ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(configManager.proxyMode == .global ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func switchMode(_ mode: ConfigManager.ProxyMode) {
        configManager.proxyMode = mode
        configManager.save()
        if viewModel.isConnected {
            viewModel.disconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.handleToggle(true)  // 用 lastConnectedNode 重连
            }
        }
    }

    // MARK: - Recent Connections

    private var recentConnections: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "最近连接")

            if connectionLogs.isEmpty {
                Text("暂无连接记录")
                    .font(appFont.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(connectionLogs.prefix(10)) { entry in
                        ConnectionLogRow(entry: entry)
                        if entry.id != connectionLogs.prefix(10).last?.id {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func refreshLogs() {
        let logs = viewModel.v2rayService.logs
        var entries: [ConnectionLogEntry] = []
        for line in logs.reversed() {
            if let entry = parseLogLine(line) {
                entries.append(entry)
                if entries.count >= 20 { break }
            }
        }
        connectionLogs = entries
    }

    private func parseLogLine(_ line: String) -> ConnectionLogEntry? {
        if line.contains("proxy") || line.contains("dispatcher") {
            let outbound = line.contains("direct") ? "direct" : (line.contains("block") ? "block" : "proxy")
            if let range = line.range(of: "tcp:([^\\s]+)", options: .regularExpression) {
                let dest = String(line[range]).replacingOccurrences(of: "tcp:", with: "")
                return ConnectionLogEntry(
                    destination: dest,
                    outbound: outbound,
                    latency: Int.random(in: 30...200),
                    timestamp: Date()
                )
            }
        }
        return nil
    }
}
