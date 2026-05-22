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
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    private init() {}
    
    func setup() {
        // Toggle item: This is the visible toggle button on the right side of the menu bar
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = toggleItem?.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(togglePressed)
            button.alignment = .right
            button.toolTip = "Left-click to toggle, Right-click for Preferences"
        }

        // First separator (spacerA): initially placed left of toggle.
        spacerItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = spacerItem?.button {
            button.title = "│"
            button.isEnabled = false
        }

        // Second separator (spacerB): initially placed left of spacerA.
        settingsSpacerItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = settingsSpacerItem?.button {
            button.title = "│"
            button.isEnabled = false
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
            MenuTracker.shared.stopTracking()
            isCollapsed.toggle()
            
            if !isCollapsed {
                MenuTracker.shared.startTracking(delay: AppSettings.shared.manualAutoCollapseDelay.rawValue) {
                    HiderModule.shared.isCollapsed = true
                }
            }
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
        guard let toggle = toggleItem, let spacerA = spacerItem, let spacerB = settingsSpacerItem else { return }
        
        let toggleX = toggle.button?.window?.frame.minX ?? 0
        let spacerAX = spacerA.button?.window?.frame.minX ?? 0
        let spacerBX = spacerB.button?.window?.frame.minX ?? 0
        
        // Determine which spacer is physically on the right (closer to the toggle)
        let aIsRight = (spacerAX != 0 && spacerBX != 0) ? (spacerAX > spacerBX) : true
        
        let rightSpacer = aIsRight ? spacerA : spacerB
        let rightX = aIsRight ? spacerAX : spacerBX
        
        let leftSpacer = aIsRight ? spacerB : spacerA
        let leftX = aIsRight ? spacerBX : spacerAX
        
        // Detect if either is wrongly placed to the right of toggleItem
        let isRightSpacerWrong = (toggleX != 0 && rightX != 0) && (rightX > toggleX)
        let isLeftSpacerWrong = (toggleX != 0 && leftX != 0) && (leftX > toggleX)
        
        let pair = AppSettings.shared.currentTogglePair
        if let button = toggle.button {
            button.title = isCollapsed ? pair.collapsed : pair.expanded
        }
        
        toggle.length = NSStatusItem.variableLength // Toggle always stays small so it remains visible
        
        // rightSpacer acts as the "toggle" separator
        if isRightSpacerWrong {
            rightSpacer.length = 15
            rightSpacer.button?.isHidden = false
        } else {
            rightSpacer.length = isCollapsed ? maxSpacerLength() : 15
            rightSpacer.button?.isHidden = isCollapsed
        }
        
        // leftSpacer acts as the "always hidden" separator
        if isLeftSpacerWrong {
            leftSpacer.length = 15
            leftSpacer.button?.isHidden = false
        } else {
            leftSpacer.length = isSettingsWindowVisible ? 15 : maxSpacerLength()
            leftSpacer.button?.isHidden = !isSettingsWindowVisible
        }
        
        // Update tooltips to reflect their dynamic roles
        rightSpacer.button?.toolTip = "Cmd+Drag icons to the LEFT of this divider to hide them!"
        leftSpacer.button?.toolTip = "Items to the right of this divider are visible only while Settings is open."
    }
}

