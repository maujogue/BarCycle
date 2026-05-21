import Cocoa
import Carbon

private var gHotKeyRef: EventHotKeyRef?
private var gHandlerRef: EventHandlerRef?

private func hotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        if !HUDWindow.shared.isVisible {
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
        checkAccessibilityPermissions()
        HiderModule.shared.setup()
        setupGlobalEventHandler()
        BarCycleApp.registerHotKey()
        
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
    }
    
    private func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        print("BarCycle: Accessibility trusted status: \(trusted)")
        
        if !trusted {
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
        
        let hotKeyID = EventHotKeyID(signature: 0x42415243, id: 1)
        let registerStatus = RegisterEventHotKey(
            48,
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

extension HUDWindow {
    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        handleFlagsChanged(with: event)
    }
}
