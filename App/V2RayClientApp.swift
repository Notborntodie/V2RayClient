import SwiftUI

@main
struct V2RayClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MainView()
                .environmentObject(MainViewModel.shared)
        } label: {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(MainViewModel.shared.isRunning ? .green : .red)
        }
    }
}
