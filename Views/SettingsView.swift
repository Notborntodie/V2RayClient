import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var appFont: AppFont
    @State private var configImportPath = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 代理模式
                VStack(alignment: .leading, spacing: 12) {
                    Text("代理模式")
                        .font(appFont.headline)

                    HStack(spacing: 16) {
                        Button(action: { viewModel.proxyMode = .rule }) {
                            VStack(spacing: 10) {
                                Image(systemName: viewModel.proxyMode == .rule ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 28))
                                    .foregroundColor(viewModel.proxyMode == .rule ? .accentColor : .gray)
                                Text("规则代理")
                                    .font(appFont.body)
                                Text("国内直连")
                                    .font(appFont.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(viewModel.proxyMode == .rule ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.proxyMode == .rule ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.proxyMode = .global }) {
                            VStack(spacing: 10) {
                                Image(systemName: viewModel.proxyMode == .global ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 28))
                                    .foregroundColor(viewModel.proxyMode == .global ? .accentColor : .gray)
                                Text("全局代理")
                                    .font(appFont.body)
                                Text("全部走代理")
                                    .font(appFont.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(viewModel.proxyMode == .global ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.proxyMode == .global ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(.regularMaterial)
                .cornerRadius(16)

                // 端口设置
                VStack(alignment: .leading, spacing: 12) {
                    Text("本地端口")
                        .font(appFont.headline)

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SOCKS5")
                                .font(appFont.caption)
                            TextField("", value: $viewModel.socksPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .font(appFont.body)
                                .frame(width: 100)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HTTP")
                                .font(appFont.caption)
                            TextField("", value: $viewModel.httpPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .font(appFont.body)
                                .frame(width: 100)
                        }
                        Spacer()
                    }
                }
                .padding(20)
                .background(.regularMaterial)
                .cornerRadius(16)

                // 日志和启动
                VStack(alignment: .leading, spacing: 12) {
                    Text("其他")
                        .font(appFont.headline)

                    VStack(spacing: 12) {
                        HStack {
                            Text("日志级别")
                                .font(appFont.body)
                            Spacer()
                            Picker("", selection: $viewModel.logLevel) {
                                ForEach(viewModel.logLevels, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }

                        Toggle("开机自动启动", isOn: $viewModel.autoStartAtLogin)
                            .font(appFont.body)

                        Toggle("自动更新订阅", isOn: $viewModel.autoUpdateSubscriptions)
                            .font(appFont.body)
                    }
                }
                .padding(20)
                .background(.regularMaterial)
                .cornerRadius(16)

                // 字体大小
                VStack(alignment: .leading, spacing: 12) {
                    Text("字体大小")
                        .font(appFont.headline)

                    HStack(spacing: 16) {
                        Button(action: { appFont.decrease() }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                        }
                        .buttonStyle(.plain)
                        .disabled(appFont.scale == 0)

                        Text(appFont.scaleLabel)
                            .font(appFont.title2)
                            .frame(minWidth: 60)

                        Button(action: { appFont.increase() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                        }
                        .buttonStyle(.plain)
                        .disabled(appFont.scale == 3)

                        Spacer()

                        Text("⌘+ / ⌘-")
                            .font(appFont.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
                .background(.regularMaterial)
                .cornerRadius(16)

                // 关于
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于")
                        .font(appFont.headline)

                    HStack {
                        Text("版本")
                            .font(appFont.body)
                        Spacer()
                        Text("1.0")
                            .font(appFont.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
                .background(.regularMaterial)
                .cornerRadius(16)

                // 保存按钮
                Button(action: { viewModel.save() }) {
                    Text("保存设置")
                        .font(appFont.headline)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }
}