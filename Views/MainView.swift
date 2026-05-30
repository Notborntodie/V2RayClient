import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("didAutoOpenConsole") private var didAutoOpen = false

    var body: some View {
        VStack(spacing: 12) {
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.system(size: 13))
                    .foregroundColor(statusColor)
            }
            .padding(.top, 8)

            // Open console
            Button(action: { openWindow(id: "console") }) {
                Label("打开控制台", systemImage: "macbook.gen2")
                    .font(.system(size: 12))
                    .frame(width: 140)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            // Toggle button
            Button(action: { viewModel.toggleService() }) {
                Text(viewModel.isRunning ? "停止" : "启动")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 100)
                    .padding(.vertical, 6)
                    .background(viewModel.isRunning ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(viewModel.isRunning ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isChecking)

            if viewModel.isChecking {
                ProgressView()
                    .scaleEffect(0.7)
            }

            // Proxy toggle
            if viewModel.isRunning {
                HStack(spacing: 8) {
                    Text("系统代理")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Toggle("", isOn: Binding(
                        get: { viewModel.proxyEnabled },
                        set: { _ in viewModel.toggleProxy() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }

            // Error
            if let error = viewModel.lastError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 200)
        .onAppear {
            if !didAutoOpen {
                didAutoOpen = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    openWindow(id: "console")
                }
            }
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
