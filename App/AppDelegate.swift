import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var viewModel: MainViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 断开连接并清理代理设置
        viewModel?.disconnect()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "V2Ray")
            button.action = #selector(statusBarClicked)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "显示主窗口", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "连接", action: #selector(connectAction), keyEquivalent: "")
        menu.addItem(withTitle: "断开", action: #selector(disconnectAction), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quitAction), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func statusBarClicked() {
        showMainWindow()
    }

    @objc private func showMainWindow() {
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func connectAction() {
        if let node = viewModel?.selectedNode {
            viewModel?.connect(to: node)
        }
    }

    @objc private func disconnectAction() {
        viewModel?.disconnect()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
