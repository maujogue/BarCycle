import Cocoa

class OverlayBadgeView: NSView {
    let item: StatusItemInfo
    let index: Int
    let iconAreaHeight: CGFloat
    var isSelected = false {
        didSet {
            updateAppearance()
        }
    }
    
    private let selectionOutlineView = NSView()
    private let capsuleView = NSView()
    private let numberLabel = NSTextField(labelWithString: "")
    
    init(item: StatusItemInfo, index: Int, iconAreaHeight: CGFloat) {
        self.item = item
        self.index = index
        self.iconAreaHeight = iconAreaHeight
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        wantsLayer = true
        
        // Selection outline around the status item icon (initially hidden/clear)
        selectionOutlineView.wantsLayer = true
        selectionOutlineView.layer?.borderWidth = 2.0
        selectionOutlineView.layer?.cornerRadius = 5.0
        selectionOutlineView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectionOutlineView)
        
        // Circular badge view with white border
        capsuleView.wantsLayer = true
        capsuleView.layer?.cornerRadius = 8.0
        capsuleView.layer?.masksToBounds = true
        capsuleView.layer?.borderWidth = 1.5
        capsuleView.layer?.borderColor = NSColor.white.cgColor
        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capsuleView)
        
        // Shadow for the badge
        capsuleView.layer?.shadowColor = NSColor.black.cgColor
        capsuleView.layer?.shadowOpacity = 0.3
        capsuleView.layer?.shadowOffset = CGSize(width: 0, height: -1)
        capsuleView.layer?.shadowRadius = 1
        
        // Number label inside the circular badge
        numberLabel.stringValue = "\(index + 1)"
        numberLabel.alignment = .center
        numberLabel.isBordered = false
        numberLabel.drawsBackground = false
        numberLabel.isEditable = false
        numberLabel.isSelectable = false
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.addSubview(numberLabel)
        
        // AutoLayout: outline is pinned to the TOP of the view with a FIXED height
        // matching the actual menu bar thickness. Badge hangs off the bottom-right corner.
        NSLayoutConstraint.activate([
            // Selection outline: pinned to top, fixed height = menu bar
            selectionOutlineView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            selectionOutlineView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            selectionOutlineView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            selectionOutlineView.heightAnchor.constraint(equalToConstant: iconAreaHeight),
            
            // Number badge circle at the bottom-right corner of the outline
            capsuleView.widthAnchor.constraint(equalToConstant: 16),
            capsuleView.heightAnchor.constraint(equalToConstant: 16),
            capsuleView.centerXAnchor.constraint(equalTo: selectionOutlineView.trailingAnchor),
            capsuleView.centerYAnchor.constraint(equalTo: selectionOutlineView.bottomAnchor),
            
            numberLabel.centerXAnchor.constraint(equalTo: capsuleView.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor)
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .settingsChanged, object: nil)
        
        updateAppearance()
    }
    
    @objc private func settingsChanged() {
        updateAppearance()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateAppearance() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            let bgCol = AppSettings.shared.unselectedBgColor
            let textCol = AppSettings.shared.unselectedTextColor
            
            capsuleView.layer?.backgroundColor = bgCol.cgColor
            numberLabel.textColor = textCol
            numberLabel.font = NSFont.boldSystemFont(ofSize: 10)
            
            if isSelected {
                selectionOutlineView.layer?.borderColor = bgCol.cgColor
                selectionOutlineView.layer?.backgroundColor = NSColor.clear.cgColor
                selectionOutlineView.isHidden = false
            } else {
                selectionOutlineView.layer?.borderColor = NSColor.clear.cgColor
                selectionOutlineView.isHidden = true
            }
        }, completionHandler: nil)
    }
    
    override func mouseUp(with event: NSEvent) {
        if let window = window as? HUDWindow {
            window.selectAndTrigger(item: item)
        }
    }
}

class HUDWindow: NSPanel {
    static let shared = HUDWindow()
    
    private var allItems = [StatusItemInfo]()
    private var filteredItems = [StatusItemInfo]()
    private var selectedIndex = 0
    private var lastModifiers: NSEvent.ModifierFlags = []
    private var backwardTimer: Timer?
    
    private var wasHiderCollapsed = false
    private var typedNumberBuffer = ""
    
    private var menuMonitorTimer: Timer?
    private var menuCheckCount = 0
    private var wasMenuDetected = false
    
    override var canBecomeKey: Bool {
        return true
    }
    
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        animationBehavior = .none
        setupWindow()
    }
    
    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    func showHUD() {
        menuMonitorTimer?.invalidate()
        menuMonitorTimer = nil
        
        wasHiderCollapsed = HiderModule.shared.isCollapsed
        if wasHiderCollapsed {
            HiderModule.shared.isCollapsed = false
            
            // Wait for menu bar re-layout to complete before scanning and showing HUD.
            // 0.08 seconds (80ms) is the sweet spot for an instantaneous, single-stage experience.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self = self else { return }
                self.setupAndShowHUDWindow()
            }
        } else {
            setupAndShowHUDWindow()
        }
    }
    
    private func setupAndShowHUDWindow() {
        lastModifiers = NSEvent.modifierFlags
        BarCycleApp.unregisterHotKey()
        
        allItems = WindowScanner.shared.scanStatusItems()
        filterAndPopulate()
        
        typedNumberBuffer = ""
        
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        makeFirstResponder(nil)
    }
    
    func dismissHUD(triggerSelected: Bool) {
        stopBackwardTimer()
        let selectedItem = (selectedIndex >= 0 && selectedIndex < filteredItems.count) ? filteredItems[selectedIndex] : nil
        
        orderOut(nil)
        BarCycleApp.registerHotKey()
        
        if triggerSelected, let item = selectedItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                WindowScanner.shared.clickStatusItem(item)
                self.startMenuMonitoringTimer()
            }
        } else {
            if wasHiderCollapsed {
                HiderModule.shared.isCollapsed = true
            }
        }
    }
    
    func selectAndTrigger(item: StatusItemInfo) {
        stopBackwardTimer()
        orderOut(nil)
        BarCycleApp.registerHotKey()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            WindowScanner.shared.clickStatusItem(item)
            self.startMenuMonitoringTimer()
        }
    }
    
    private func startMenuMonitoringTimer() {
        menuMonitorTimer?.invalidate()
        menuCheckCount = 0
        wasMenuDetected = false
        
        // Start a timer checking every 0.2 seconds for dropdown menu visibility
        menuMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let menuVisible = self.isMenuWindowOpen()
            self.menuCheckCount += 1
            
            if menuVisible {
                self.wasMenuDetected = true
            }
            
            // Grace period: check for 5 iterations (1.0 second) to see if a menu opens.
            // If we detected a menu and it has now closed, OR if 1.0 second passed without any menu opening, collapse!
            if (self.wasMenuDetected && !menuVisible) || (!self.wasMenuDetected && self.menuCheckCount >= 5) {
                timer.invalidate()
                self.menuMonitorTimer = nil
                
                if self.wasHiderCollapsed {
                    HiderModule.shared.isCollapsed = true
                }
            }
        }
    }
    
    private func isMenuWindowOpen() -> Bool {
        let options = CGWindowListOption.optionOnScreenOnly
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        for window in windowList {
            if let layer = window[kCGWindowLayer as String] as? Int32 {
                // Layer 101 is kCGPopUpMenuWindowLevel, which is used for all dropdown and popup menus
                if layer == 101 {
                    return true
                }
            }
        }
        return false
    }


    
    private func filterAndPopulate() {
        filteredItems = allItems
        
        contentView?.subviews.forEach { $0.removeFromSuperview() }
        
        guard !filteredItems.isEmpty else { return }
        
        let screen = WindowScanner.activeScreen()
        let screenFrame = screen.frame
        
        // Use NSStatusBar.system.thickness for the menu bar content height,
        // then add 6pt so the outline fully wraps the icons with breathing room.
        let menuBarHeight = NSStatusBar.system.thickness + 6
        let badgeOverhang: CGFloat = 10 // extra space below menu bar for the number circle
        let windowHeight = menuBarHeight + badgeOverhang
        
        // Position window flush with the very top of the screen
        let windowFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.size.width,
            height: windowHeight
        )
        setFrame(windowFrame, display: true, animate: false)
        
        // Add badge subviews — each one spans the full window height
        // with the outline constrained to the top menuBarHeight points.
        for (index, item) in filteredItems.enumerated() {
            let itemWidth = item.bounds.size.width
            let relativeX = item.bounds.origin.x - screenFrame.origin.x
            
            let badgeViewFrame = NSRect(
                x: relativeX - 2,
                y: 0,
                width: itemWidth + 12,
                height: windowHeight
            )
            
            let badgeView = OverlayBadgeView(item: item, index: index, iconAreaHeight: menuBarHeight)
            badgeView.frame = badgeViewFrame
            contentView?.addSubview(badgeView)
        }
        
        selectedIndex = 0
        updateSelectionHighlight()
    }
    
    private func updateSelectionHighlight() {
        for view in contentView?.subviews ?? [] {
            guard let badgeView = view as? OverlayBadgeView else { continue }
            badgeView.isSelected = (badgeView.index == selectedIndex)
        }
    }
    
    func cycleSelection(forward: Bool) {
        guard !filteredItems.isEmpty else { return }
        typedNumberBuffer = ""
        
        if forward {
            selectedIndex = (selectedIndex + 1) % filteredItems.count
        } else {
            selectedIndex = (selectedIndex - 1 + filteredItems.count) % filteredItems.count
        }
        updateSelectionHighlight()
    }
    
    func handleFlagsChanged(with event: NSEvent) {
        let modifiers = event.modifierFlags
        if isVisible {
            if !modifiers.contains(.option) {
                stopBackwardTimer()
                dismissHUD(triggerSelected: true)
            } else if modifiers.contains(.shift) {
                startBackwardTimer()
            } else {
                stopBackwardTimer()
            }
        } else {
            stopBackwardTimer()
        }
        lastModifiers = modifiers
    }
    
    private func startBackwardTimer() {
        guard backwardTimer == nil else { return }
        cycleSelection(forward: false)
        
        backwardTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.cycleSelection(forward: false)
        }
    }
    
    private func stopBackwardTimer() {
        backwardTimer?.invalidate()
        backwardTimer = nil
    }
    
    override func cancelOperation(_ sender: Any?) {
        dismissHUD(triggerSelected: false)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        if keyCode == 48 { // Tab
            let shiftPressed = event.modifierFlags.contains(.shift)
            cycleSelection(forward: !shiftPressed)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        
        switch keyCode {
        case 53: // Escape
            dismissHUD(triggerSelected: false)
            
        case 36: // Return / Enter
            dismissHUD(triggerSelected: true)
            
        case 123: // Arrow Left
            cycleSelection(forward: false)
            
        case 124: // Arrow Right
            cycleSelection(forward: true)
            
        case 125: // Arrow Down
            cycleSelection(forward: true)
            
        case 126: // Arrow Up
            cycleSelection(forward: false)
            
        case 48: // Tab
            let shiftPressed = event.modifierFlags.contains(.shift)
            cycleSelection(forward: !shiftPressed)
            
        case 51: // Backspace / Delete
            if !typedNumberBuffer.isEmpty {
                typedNumberBuffer.removeLast()
                if let targetNumber = Int(typedNumberBuffer) {
                    let targetIndex = targetNumber - 1
                    if targetIndex >= 0 && targetIndex < filteredItems.count {
                        selectedIndex = targetIndex
                        updateSelectionHighlight()
                    }
                }
            }
            
        default:
            if let chars = event.charactersIgnoringModifiers, let firstChar = chars.first, firstChar.isNumber {
                typedNumberBuffer.append(firstChar)
                if let targetNumber = Int(typedNumberBuffer) {
                    let targetIndex = targetNumber - 1
                    if targetIndex >= 0 && targetIndex < filteredItems.count {
                        selectedIndex = targetIndex
                        updateSelectionHighlight()
                    } else {
                        // If typing another digit makes it out of bounds, restart buffer with the new digit
                        typedNumberBuffer = String(firstChar)
                        if let resetNumber = Int(typedNumberBuffer) {
                            let resetIndex = resetNumber - 1
                            if resetIndex >= 0 && resetIndex < filteredItems.count {
                                selectedIndex = resetIndex
                                updateSelectionHighlight()
                            }
                        }
                    }
                }
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
