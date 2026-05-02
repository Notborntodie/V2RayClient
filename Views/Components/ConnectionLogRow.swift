import SwiftUI

struct ConnectionLogRow: View {
    let entry: ConnectionLogEntry
    @EnvironmentObject var appFont: AppFont

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.outbound == "proxy" ? "arrow.up.forward" : (entry.outbound == "block" ? "xmark.shield" : "arrow.triangle.turn.up.right"))
                .font(appFont.caption)
                .foregroundColor(entry.outbound == "proxy" ? .accentColor : (entry.outbound == "block" ? .red : .secondary))
                .frame(width: 16)

            Text(entry.destination)
                .font(appFont.monoCaption)
                .lineLimit(1)
                .frame(minWidth: 140, alignment: .leading)

            Text("→")
                .font(appFont.caption2)
                .foregroundColor(.secondary)

            Text(entry.outbound)
                .font(appFont.caption2)
                .foregroundColor(outboundColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(outboundColor.opacity(0.12))
                .clipShape(Capsule())

            Spacer()

            if entry.latency >= 0 {
                Text("\(entry.latency)ms")
                    .font(appFont.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Text(entry.timeText)
                .font(appFont.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private var outboundColor: Color {
        switch entry.outbound {
        case "proxy": return .accentColor
        case "direct": return .green
        case "block": return .red
        default: return .secondary
        }
    }
}

struct ConnectionLogEntry: Identifiable {
    let id = UUID()
    let destination: String
    let outbound: String
    let latency: Int
    let timestamp: Date

    var timeText: String {
        let elapsed = Date().timeIntervalSince(timestamp)
        if elapsed < 60 { return "\(Int(elapsed))s前" }
        if elapsed < 3600 { return "\(Int(elapsed/60))m前" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
