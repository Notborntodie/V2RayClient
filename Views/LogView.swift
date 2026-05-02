import SwiftUI

struct LogView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject var appFont: AppFont
    @State private var filter: LogFilter = .all
    @State private var searchText = ""

    enum LogFilter: String, CaseIterable {
        case all = "全部"
        case proxy = "代理"
        case direct = "直连"
        case blocked = "阻止"
    }

    var filteredLogs: [String] {
        var result = Array(viewModel.v2rayService.logs.reversed())
        if !searchText.isEmpty {
            result = result.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
        switch filter {
        case .all: return result
        case .proxy: return result.filter { $0.contains("proxy") }
        case .direct: return result.filter { $0.contains("direct") }
        case .blocked: return result.filter { $0.contains("block") }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(appFont.caption)
                    TextField("搜索日志...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(appFont.caption)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
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

                Picker("筛选", selection: $filter) {
                    ForEach(LogFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                Spacer()

                Text("\(filteredLogs.count) 条")
                    .font(appFont.caption)
                    .foregroundColor(.secondary)

                Button(action: copyLogs) {
                    Image(systemName: "doc.on.doc")
                        .font(appFont.caption)
                }
                .buttonStyle(.plain)
                .help("复制日志")

                Button(action: clearLogs) {
                    Image(systemName: "trash")
                        .font(appFont.caption)
                }
                .buttonStyle(.plain)
                .help("清空日志")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if filteredLogs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: appFont.iconLarge))
                        .foregroundColor(.secondary)
                    Text("暂无日志")
                        .font(appFont.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredLogs.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 6) {
                        if filteredLogs[index].contains("[Warning]") || filteredLogs[index].contains("[Error]") {
                            Image(systemName: filteredLogs[index].contains("[Error]") ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                                .foregroundColor(levelColor(for: filteredLogs[index]))
                                .font(appFont.caption2)
                        }
                        Text(filteredLogs[index])
                            .font(appFont.monoCaption)
                            .foregroundColor(levelColor(for: filteredLogs[index]))
                            .textSelection(.enabled)
                        Spacer()
                    }
                    .padding(.vertical, 1)
                }
                .listStyle(.inset)
            }
        }
    }

    private func levelColor(for text: String) -> Color {
        if text.contains("[Warning]") { return .yellow }
        if text.contains("[Error]") { return .red }
        if text.contains("[Debug]") { return .gray }
        if text.contains("[Info]") { return .blue }
        return .primary
    }

    private func clearLogs() {
        viewModel.v2rayService.logs.removeAll()
    }

    private func copyLogs() {
        let text = filteredLogs.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
