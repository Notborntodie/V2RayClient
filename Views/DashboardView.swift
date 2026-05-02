import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject var appFont: AppFont
    @State private var connectionLogs: [ConnectionLogEntry] = []
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                connectionHeroCard
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
        HStack(spacing: 0) {
            // Upload
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                        .font(appFont.caption)
                        .foregroundColor(.blue)
                    Text("上传")
                        .font(appFont.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(viewModel.trafficStats.uploadSpeedText)
                    .font(appFont.title2)
                    .monospacedDigit()
                Text("总计 \(viewModel.trafficStats.totalUploadText)")
                    .font(appFont.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)

            Divider()
                .padding(.vertical, 16)

            // Download
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                        .font(appFont.caption)
                        .foregroundColor(.green)
                    Text("下载")
                        .font(appFont.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(viewModel.trafficStats.downloadSpeedText)
                    .font(appFont.title2)
                    .monospacedDigit()
                Text("总计 \(viewModel.trafficStats.totalDownloadText)")
                    .font(appFont.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
