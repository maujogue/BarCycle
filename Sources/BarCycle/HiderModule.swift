import Cocoa

class HiderModule {
    static let shared = HiderModule()
    
    private var toggleItem: NSStatusItem?
    private var spacerItem: NSStatusItem?
    private var settingsSpacerItem: NSStatusItem?
    private var isSettingsWindowVisible = false
    
    private let collapsedWidthKey = "BarCycle_CollapsedWidth"
    private let isCollapsedKey = "BarCycle_IsCollapsed"
    
    var isCollapsed: Bool {
        get { UserDefaults.standard.bool(forKey: isCollapsedKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: isCollapsedKey)
            updateSpacerWidths()
        }
    }
    
    private init() {}
    
    func setup() {
        // Spacer item: This resides to the left of the toggle button.
        // Icons to the left of this spacer will be pushed off screen when collapsed.
        spacerItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = spacerItem?.button {
            button.title = "│"
            button.isEnabled = false // Cannot click it directly
            button.toolTip = "Cmd+Drag icons to the LEFT of this divider to hide them!"
        }

        // Toggle item: This is the visible toggle button on the right side of the menu bar
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = toggleItem?.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(togglePressed)
            button.toolTip = "Left-click to toggle, Right-click for Preferences"
        }

        // Settings spacer item: this sits to the right of the toggle button.
        // When Settings is closed, it pushes the items after it offscreen.
        settingsSpacerItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = settingsSpacerItem?.button {
            button.title = "│"
            button.isEnabled = false
            button.toolTip = "Items to the right of this divider are visible only while Settings is open."
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsChanged), name: .settingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsWindowVisibilityChanged(_:)), name: .settingsWindowVisibilityChanged, object: nil)
        
        // Set initial state
        updateSpacerWidths()
    }
    
    @objc private func togglePressed() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            SettingsWindow.shared.presentWindow()
        } else {
            isCollapsed.toggle()
        }
    }
    
    @objc private func onSettingsChanged() {
        updateSpacerWidths()
    }

    @objc private func onSettingsWindowVisibilityChanged(_ notification: Notification) {
        let visible = (notification.userInfo?["visible"] as? Bool) ?? false
        isSettingsWindowVisible = visible
        updateSpacerWidths()
    }
    
    private func maxSpacerLength() -> CGFloat {
        NSScreen.screens.map { $0.frame.width }.max() ?? 1500
    }

    func updateSpacerWidths() {
        guard let spacer = spacerItem else { return }
        
        let pair = AppSettings.shared.currentTogglePair
        if isCollapsed {
            // When collapsed, set length to push items off-screen. Must be at least as wide
            // as the widest connected display so external monitors are also covered.
            spacer.length = maxSpacerLength()
            if let button = toggleItem?.button {
                button.title = pair.collapsed
            }
        } else {
            // When expanded, set standard length showing the divider.
            spacer.length = 15
            if let button = toggleItem?.button {
                button.title = pair.expanded
            }
        }

        if let spacerButton = spacer.button {
            spacerButton.isHidden = isCollapsed
        }

        guard let settingsSpacer = settingsSpacerItem else { return }
        settingsSpacer.length = isSettingsWindowVisible ? 15 : maxSpacerLength()
        if let settingsSpacerButton = settingsSpacer.button {
            settingsSpacerButton.isHidden = !isSettingsWindowVisible
        }
    }
}

