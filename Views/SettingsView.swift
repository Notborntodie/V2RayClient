import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var configImportPath = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                proxySettingsSection
                subscriptionSettingsSection
                advancedSection
            }
            .padding(24)
        }
    }

    // MARK: - Proxy Settings

    private var proxySettingsSection: some View {
        Form {
            Section("本地代理端口") {
                LabeledContent("SOCKS5 端口") {
                    TextField("", value: $viewModel.socksPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                LabeledContent("HTTP 端口") {
                    TextField("", value: $viewModel.httpPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            Section("日志") {
                LabeledContent("日志级别") {
                    Picker("", selection: $viewModel.logLevel) {
                        ForEach(viewModel.logLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .frame(width: 120)
                }
            }

            Section {
                Button("保存设置") {
                    viewModel.save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Subscription Settings

    private var subscriptionSettingsSection: some View {
        Form {
            Section("自动更新") {
                Toggle("自动更新订阅", isOn: $viewModel.autoUpdateSubscriptions)
            }

            Section("导入") {
                HStack {
                    TextField("配置文件路径", text: $configImportPath)
                        .textFieldStyle(.roundedBorder)
                    Button("浏览") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.json]
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            configImportPath = url.path
                        }
                    }
                    Button("导入") {
                        if let node = viewModel.importConfig(from: configImportPath) {
                            viewModel.configManager.addNode(node)
                            configImportPath = ""
                        }
                    }
                    .disabled(configImportPath.isEmpty)
                }
            }

            Section {
                Button("保存设置") {
                    viewModel.save()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced Settings

    private var advancedSection: some View {
        Form {
            Section("启动") {
                Toggle("开机自动启动", isOn: $viewModel.autoStartAtLogin)
            }

            Section("关于") {
                LabeledContent("版本") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
                LabeledContent("V2Ray 核心") {
                    Text("内置")
                }
            }

            Section {
                Button("保存设置") {
                    viewModel.save()
                }
            }
        }
        .formStyle(.grouped)
    }
}
