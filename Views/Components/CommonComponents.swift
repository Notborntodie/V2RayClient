import SwiftUI

// MARK: - 状态指示灯（带脉冲动画）

struct StatusIndicator: View {
    let isConnected: Bool
    var size: CGFloat? = nil
    @EnvironmentObject var appFont: AppFont
    @State private var pulse = false

    private var dotSize: CGFloat { size ?? appFont.statusDot }

    var body: some View {
        ZStack {
            if isConnected {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: dotSize * 2, height: dotSize * 2)
                    .scaleEffect(pulse ? 1.0 : 0.6)
                    .opacity(pulse ? 0.4 : 0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
            }
            Circle()
                .fill(isConnected ? Color.green : Color.gray.opacity(0.6))
                .frame(width: dotSize, height: dotSize)
        }
        .onAppear { if isConnected { pulse = true } }
        .onChange(of: isConnected) { connected in pulse = connected }
    }
}

// MARK: - 延迟标签

struct LatencyBadge: View {
    let latency: TimeInterval?
    @EnvironmentObject var appFont: AppFont

    var color: Color {
        guard let latency = latency else { return .gray }
        if latency < 0 { return .red }
        if latency < 0.1 { return .green }
        if latency < 0.3 { return .yellow }
        return .orange
    }

    var body: some View {
        Text(latencyText)
            .font(appFont.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.clipShape(Capsule()))
    }

    private var latencyText: String {
        guard let latency = latency else { return "N/A" }
        if latency < 0 { return "超时" }
        return "\(Int(latency * 1000))ms"
    }
}

// MARK: - 流量速度视图

struct SpeedView: View {
    let upload: String
    let download: String
    @EnvironmentObject var appFont: AppFont

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(upload)
                    .font(appFont.monoCaption)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "arrow.up")
                    .font(appFont.caption2)
                    .foregroundColor(.blue)
            }

            Label {
                Text(download)
                    .font(appFont.monoCaption)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "arrow.down")
                    .font(appFont.caption2)
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Section 标题

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String = ""
    @EnvironmentObject var appFont: AppFont

    var body: some View {
        HStack {
            Text(title)
                .font(appFont.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
            if let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(appFont.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
    }
}
