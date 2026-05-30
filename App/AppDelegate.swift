import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    private var consoleWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showConsole()
        }
    }

    @objc func showConsole() {
        if let window = consoleWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let viewModel = MainViewModel.shared
        let consoleView = ConsoleView()
            .environmentObject(viewModel)
        let hosting = NSHostingView(rootView: consoleView)
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 500)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "V2Ray"
        window.center()
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        consoleWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = BrewManager.shared.disableSystemProxy()
    }
}
