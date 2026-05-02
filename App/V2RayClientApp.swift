import SwiftUI

@main
struct V2RayClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var appFont = AppFont.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
                .environmentObject(appFont)
                .onAppear {
                    if let window = NSApp.windows.first {
                        window.title = "V2Ray Client"
                        window.minSize = NSSize(width: 860, height: 560)
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("添加节点") {
                    // TODO: show add node sheet
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("添加订阅") {
                    // TODO: show add subscription sheet
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandMenu("连接") {
                Button("连接") {
                    if let node = viewModel.selectedNode {
                        viewModel.connect(to: node)
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(viewModel.selectedNode == nil)

                Button("断开") {
                    viewModel.disconnect()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(!viewModel.isConnected)

                Divider()

                Button("测试所有节点延迟") {
                    Task { await viewModel.testAllLatency() }
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("更新所有订阅") {
                    Task { await viewModel.updateAllSubscriptions() }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }

            // 字体大小 Cmd+/Cmd-
            CommandMenu("显示") {
                Button("放大字体") {
                    appFont.increase()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("缩小字体") {
                    appFont.decrease()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("重置字体") {
                    appFont.scale = 1
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Text("当前字体: \(appFont.scaleLabel)")
            }
        }

        Settings {
            SettingsView()
        }
    }
}
