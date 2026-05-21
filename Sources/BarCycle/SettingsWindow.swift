import Cocoa
import SwiftUI

class SettingsWindow: NSWindow, NSWindowDelegate {
    static let shared = SettingsWindow()

    private init() {
        let contentRect = NSRect(x: 0, y: 0, width: 1100, height: 780)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.title = "BarCycle Preferences"
        self.isReleasedWhenClosed = false
        self.titlebarAppearsTransparent = false
        self.minSize = NSSize(width: 940, height: 640)
        self.center()
        self.delegate = self

        let hosting = NSHostingController(rootView: SettingsRootView())
        self.contentViewController = hosting
        self.setContentSize(NSSize(width: 1100, height: 780))
    }

    func presentWindow() {
        NSApp.setActivationPolicy(.regular)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .settingsWindowVisibilityChanged, object: self, userInfo: ["visible": true])
    }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: .settingsWindowVisibilityChanged, object: self, userInfo: ["visible": false])
        NSApp.setActivationPolicy(.accessory)
    }
}
