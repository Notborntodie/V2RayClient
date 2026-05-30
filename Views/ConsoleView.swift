import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            Divider()
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    controlsSection
                    statusSection
                    logSection
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            if let latency = viewModel.lastLatency {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(latency)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Start/Stop button
            Button(action: { viewModel.toggleService() }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 14))
                    Text(viewModel.isRunning ? "停止服务" : "启动服务")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(viewModel.isRunning ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.isRunning ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isChecking)

            if viewModel.isChecking {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("处理中...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Proxy toggle
            HStack {
                Label("系统代理", systemImage: "network")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.proxyEnabled },
                    set: { _ in viewModel.toggleProxy() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 4)

            if let error = viewModel.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(Color(.textBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("节点")

            VStack(spacing: 6) {
                if let node = viewModel.selectedNode {
                    statusRow("节点", node.displayName)
                    statusRow("地址", "\(node.add):\(node.port)")
                    statusRow("协议", node.protocolName)
                }
                statusRow("延迟", viewModel.lastLatency ?? "检测中...")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.textBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Log

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("日志")

            if viewModel.logEntries.isEmpty {
                Text("暂无日志")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.logEntries.reversed().prefix(20))) { entry in
                        HStack(spacing: 8) {
                            Text(entry.formattedTime)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 52, alignment: .leading)
                            Text(entry.message)
                                .font(.system(size: 11))
                                .foregroundColor(
                                    entry.message.contains("异常") || entry.message.contains("失败")
                                        ? .red : .primary
                                )
                            Spacer()
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        if entry.id != viewModel.logEntries.reversed().prefix(20).last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.textBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.textBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .kerning(0.5)
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
            Spacer()
        }
    }

    private var statusColor: Color {
        if viewModel.isChecking { return .yellow }
        return viewModel.isRunning ? .green : .red
    }

    private var statusText: String {
        if viewModel.isChecking { return "处理中..." }
        return viewModel.isRunning ? "运行中" : "已停止"
    }
}
