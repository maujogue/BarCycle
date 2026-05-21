import Cocoa

class HiderModule {
    static let shared = HiderModule()
    
    private var toggleItem: NSStatusItem?
    private var spacerItem: NSStatusItem?
    
    private let collapsedWidthKey = "BarCycle_CollapsedWidth"
    private let isCollapsedKey = "BarCycle_IsCollapsed"
    
    var isCollapsed: Bool {
        get { UserDefaults.standard.bool(forKey: isCollapsedKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: isCollapsedKey)
            updateSpacerWidth()
        }
    }
    
    private init() {}
    
    func setup() {
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = toggleItem?.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(togglePressed)
            button.toolTip = "Left-click to toggle, Right-click for Preferences"
        }
        
        spacerItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = spacerItem?.button {
            button.title = "│"
            button.isEnabled = false
            button.toolTip = "Cmd+Drag icons to the LEFT of this divider to hide them!"
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsChanged), name: .settingsChanged, object: nil)
        
        updateSpacerWidth()
    }
    
    @objc private func togglePressed() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            SettingsWindow.shared.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            isCollapsed.toggle()
        }
    }
    
    @objc private func onSettingsChanged() {
        updateSpacerWidth()
    }
    
    func updateSpacerWidth() {
        guard let spacer = spacerItem else { return }
        
        let pair = AppSettings.shared.currentTogglePair
        if isCollapsed {
            spacer.length = 1500
            if let button = toggleItem?.button {
                button.title = pair.collapsed
            }
        } else {
            spacer.length = 15
            if let button = toggleItem?.button {
                button.title = pair.expanded
            }
        }
    }
}
