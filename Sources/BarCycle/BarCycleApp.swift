import Cocoa
import Carbon

// Global references to the hotkey and event handler to manage registration
private var gHotKeyRef: EventHotKeyRef?
private var gHandlerRef: EventHandlerRef?

// C-style callback for the Carbon HotKey event
private func hotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        if !HUDWindow.shared.isVisible {
            // HUD is closed, open it!
            HUDWindow.shared.showHUD()
        }
    }
    return noErr
}

@main
class BarCycleApp: NSObject, NSApplicationDelegate {
    
    static func main() {
        let app = NSApplication.shared
        let delegate = BarCycleApp()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("BarCycle: Application started.")

        // 0. Build the app menu so "BarCycle" appears next to the Apple logo
        //    whenever the activation policy is .regular (i.e. while Settings is open).
        BarCycleApp.installMainMenu()

        // 1. Check and request Accessibility permissions if needed
        checkAccessibilityPermissions()
        
        // 3. Setup the built-in Divider/Hider status items
        HiderModule.shared.setup()
        
        // 4. Install the global Carbon event handler once
        setupGlobalEventHandler()
        
        // 5. Register global keyboard shortcut Option-Tab
        BarCycleApp.registerHotKey()
        
        // 6. Setup robust local and global event monitors for modifier key tracking.
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if HUDWindow.shared.isVisible {
                HUDWindow.shared.handleFlagsChanged(with: event)
            }
            return event
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            if HUDWindow.shared.isVisible {
                DispatchQueue.main.async {
                    HUDWindow.shared.handleFlagsChanged(with: event)
                }
            }
        }

        // 7. Show Settings on launch with .regular policy so the user can immediately
        //    reach the app menu (next to the Apple logo) and the ⌘. shortcut.
        //    When the user closes Settings we fall back to .accessory.
        SettingsWindow.shared.presentWindow()
    }
    
    private func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        print("BarCycle: Accessibility trusted status: \(trusted)")
        
        if !trusted {
            // Prompt the user with an alert and option to open settings
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "BarCycle requires Accessibility permissions to locate and trigger your menu bar items.\n\nPlease enable BarCycle in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func setupGlobalEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyCallback,
            1,
            &eventType,
            nil,
            &gHandlerRef
        )
        
        if installStatus != noErr {
            print("BarCycle: Failed to install hotkey event handler (Status \(installStatus))")
        }
    }
    
    static func registerHotKey() {
        if gHotKeyRef != nil { return }
        
        let hotKeyID = EventHotKeyID(signature: 0x42415243, id: 1) // 'BARC' in hex
        let registerStatus = RegisterEventHotKey(
            48, // kVK_Tab
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &gHotKeyRef
        )
        
        if registerStatus == noErr {
            print("BarCycle: Registered global Option-Tab hotkey successfully!")
        } else {
            print("BarCycle: Failed to register global hotkey (Status \(registerStatus))")
        }
    }
    
    static func installMainMenu() {
        let mainMenu = NSMenu()

        // App menu (the one shown next to the Apple logo, in bold)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let appName = "BarCycle"

        appMenu.addItem(withTitle: "About \(appName)",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(BarCycleApp.openSettings),
            keyEquivalent: "."
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        appMenu.addItem(withTitle: "Hide \(appName)",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others",
                                    action: #selector(NSApplication.hideOtherApplications(_:)),
                                    keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())

        appMenu.addItem(withTitle: "Quit \(appName)",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close",
                           action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    @objc static func openSettings() {
        SettingsWindow.shared.presentWindow()
    }

    static func unregisterHotKey() {
        if let ref = gHotKeyRef {
            let status = UnregisterEventHotKey(ref)
            if status == noErr {
                print("BarCycle: Unregistered global Option-Tab hotkey successfully!")
            } else {
                print("BarCycle: Failed to unregister global hotkey (Status \(status))")
            }
            gHotKeyRef = nil
        }
    }
}

// Extend HUDWindow to add flagsChanged modifier support
extension HUDWindow {
    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        handleFlagsChanged(with: event)
    }
}
