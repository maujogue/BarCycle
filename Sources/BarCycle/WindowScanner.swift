import Cocoa
import CoreGraphics
import ApplicationServices
import ScreenCaptureKit

struct StatusItemInfo {
    let windowID: CGWindowID
    let ownerName: String
    var title: String
    var description: String
    let bounds: CGRect
    var image: NSImage?
    var axElement: AXUIElement?
}

class WindowScanner {
    static let shared = WindowScanner()

    private init() {}

    /// The display the user is currently interacting with — the one containing the mouse cursor.
    /// Falls back to NSScreen.main, then to the first screen.
    static func activeScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
    
    private func cleanTitle(title: String, desc: String, ownerName: String) -> String {
        let genericTitles = [
            "system status item", "status item", "menu extra", "menuextra", "statusitem", "system status",
            "systemstatusitem", "status item.", "system status item."
        ]
        
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedOwner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let isGeneric = cleanedTitle.isEmpty || 
                        genericTitles.contains(cleanedTitle.lowercased()) ||
                        cleanedTitle.lowercased() == cleanedOwner.lowercased() ||
                        cleanedTitle.lowercased().contains("control center") ||
                        cleanedTitle.lowercased().contains("systemuiserver") ||
                        cleanedTitle.lowercased().contains("controlcenter")
        
        // If title is not generic, use it!
        if !isGeneric {
            return cleanedTitle
        }
        
        // If title is generic, try parsing from description (desc)
        let cleanedDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDescGeneric = cleanedDesc.isEmpty ||
                            genericTitles.contains(cleanedDesc.lowercased()) ||
                            cleanedDesc.lowercased() == cleanedOwner.lowercased() ||
                            cleanedDesc.lowercased().contains("control center") ||
                            cleanedDesc.lowercased().contains("systemuiserver") ||
                            cleanedDesc.lowercased().contains("controlcenter")
        
        if !isDescGeneric {
            let lower = cleanedDesc.lowercased()
            
            if lower.hasPrefix("wi-fi") { return "Wi-Fi" }
            if lower.hasPrefix("bluetooth") { return "Bluetooth" }
            if lower.hasPrefix("battery") { return "Battery" }
            if lower.hasPrefix("volume") || lower.hasPrefix("sound") { return "Sound" }
            if lower.hasPrefix("clock") || lower.hasPrefix("time ") { return "Clock" }
            if lower.hasPrefix("siri") { return "Siri" }
            if lower.hasPrefix("spotlight") { return "Spotlight" }
            if lower.hasPrefix("airplay") || lower.hasPrefix("screen mirroring") { return "Screen Mirroring" }
            if lower.hasPrefix("time machine") { return "Time Machine" }
            if lower.hasPrefix("vpn") { return "VPN" }
            if lower.hasPrefix("notification center") || lower.hasPrefix("notifications") { return "Notification Center" }
            if lower.hasPrefix("input source") || lower.hasPrefix("keyboard") { return "Input Source" }
            if lower.hasPrefix("focus") || lower.hasPrefix("do not disturb") { return "Focus" }
            
            // Fallback: If it contains a comma or colon, take the prefix before the first one
            if let separatorRange = cleanedDesc.range(of: ",") {
                let part = String(cleanedDesc[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !part.isEmpty { return part }
            }
            if let separatorRange = cleanedDesc.range(of: ":") {
                let part = String(cleanedDesc[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !part.isEmpty { return part }
            }
            
            return cleanedDesc
        }
        
        // Fallback to ownerName (process name)
        return ownerName
    }
    
    // Helper to recursively find status items/menu bar items in an accessibility element
    private func findMenuBarItems(in element: AXUIElement, items: inout [AXUIElement]) {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = role as? String ?? ""
        
        if roleStr == "AXMenuBarItem" || roleStr == "AXStatusItem" {
            items.append(element)
        }
        
        var children: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let childrenList = children as? [AXUIElement] {
            for child in childrenList {
                findMenuBarItems(in: child, items: &items)
            }
        }
    }
    
    // Helper to get frame of an AXUIElement
    private func getElementFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        let posAXValue = positionValue as! AXValue
        AXValueGetValue(posAXValue, .cgPoint, &position)
        
        let sizeAXValue = sizeValue as! AXValue
        AXValueGetValue(sizeAXValue, .cgSize, &size)
        
        return CGRect(origin: position, size: size)
    }

    
    /// Scans the menu bar for status items, captures their screenshots, and queries their accessibility details.
    func scanStatusItems() -> [StatusItemInfo] {
        let options = CGWindowListOption.optionOnScreenOnly
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            print("Scanner: Failed to get window list")
            return []
        }
        
        var items = [StatusItemInfo]()
        let systemWide = AXUIElementCreateSystemWide()
        
        for window in windowList {
            guard let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let layer = window[kCGWindowLayer as String] as? Int32,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }
            
            // Filter rules for menu bar status items:
            // 1. Layer must be 25 (kCGStatusWindowLevel)
            // 2. Y coordinate must be 0 (or close to 0 in case of screen scaling/notches)
            // 3. Height must match typical menu bar height
            // 4. Exclude the "Menubar" itself (owned by Window Server, layer 24)
            // Note: We DO NOT exclude our own app here because we need to find its X position,
            // but we will filter out our own items before returning.
            guard layer == 25 else { continue }
            guard rect.origin.y >= 0 && rect.origin.y <= 10 else { continue }
            guard rect.size.height > 10 && rect.size.height <= 50 else { continue }
            guard ownerName != "Window Server" else { continue }
            
            var title = window[kCGWindowName as String] as? String ?? ""
            var desc = ""
            var axElement: AXUIElement?
            
            // 1. Try PID-based Accessibility Element resolution (highly precise & robust)
            if let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 {
                let appElement = AXUIElementCreateApplication(ownerPID)
                var axItems = [AXUIElement]()
                findMenuBarItems(in: appElement, items: &axItems)
                
                for element in axItems {
                    if let frame = getElementFrame(element) {
                        let rectCenter = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
                        let frameCenter = CGPoint(x: frame.origin.x + frame.size.width / 2, y: frame.origin.y + frame.size.height / 2)
                        let dist = hypot(rectCenter.x - frameCenter.x, rectCenter.y - frameCenter.y)
                        
                        if dist < 15 { // 15 points matching threshold
                            axElement = element
                            break
                        }
                    }
                }
            }
            
            // 2. Fallback to coordinate-based Hit-Testing if PID-based lookup didn't find the element
            if axElement == nil {
                let centerX = rect.origin.x + rect.size.width / 2
                let centerY = rect.origin.y + rect.size.height / 2
                var hitElement: AXUIElement?
                let axStatus = AXUIElementCopyElementAtPosition(systemWide, Float(centerX), Float(centerY), &hitElement)
                if axStatus == .success, let element = hitElement {
                    axElement = element
                }
            }
            
            // 3. Query properties from the resolved accessibility element
            if let element = axElement {
                var axTitle: AnyObject?
                var axDesc: AnyObject?
                
                AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &axTitle)
                AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &axDesc)
                
                if let t = axTitle as? String, !t.isEmpty {
                    title = t
                }
                if let d = axDesc as? String {
                    desc = d
                }
                
                // If title is still empty, try role description
                if title.isEmpty {
                    var axRoleDesc: AnyObject?
                    AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &axRoleDesc)
                    if let rd = axRoleDesc as? String {
                        title = rd
                    }
                }
            }
            
            // Resolve the final item title elegantly using our cleanTitle helper
            let finalTitle = cleanTitle(title: title, desc: desc, ownerName: ownerName)
            
            if desc.isEmpty {
                desc = "Status item for \(ownerName)"
            }
            
            // Capture the window's image with perfect transparency (DISABLED for maximum speed/privacy)
            let image: NSImage? = nil
            
            let item = StatusItemInfo(
                windowID: windowID,
                ownerName: ownerName,
                title: finalTitle,
                description: desc,
                bounds: rect,
                image: image,
                axElement: axElement
            )
            items.append(item)
        }
        
        // Restrict to the active display (the one containing the mouse cursor). When multiple
        // displays show the menu bar, status items appear on each; without this filter we'd
        // count duplicates from every screen.
        let activeFrame = Self.activeScreen().frame
        let activeXMin = activeFrame.origin.x
        let activeXMax = activeFrame.origin.x + activeFrame.size.width
        items = items.filter { item in
            let midX = item.bounds.origin.x + item.bounds.size.width / 2
            return midX >= activeXMin && midX < activeXMax
        }

        // Sort items from left to right (by X coordinate)
        let sortedItems = items.sorted(by: { $0.bounds.origin.x < $1.bounds.origin.x })
        
        let myProcessName = ProcessInfo.processInfo.processName
        let myAppName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "BarCycle"
        
        // Find the physical X-coordinate of our toggle arrow item
        var arrowX: CGFloat? = nil
        for item in sortedItems {
            let isMyApp = (item.ownerName == myProcessName || item.ownerName == myAppName || item.ownerName == "BarCycle" || item.ownerName.contains("BarCycle"))
            let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let isToggleTitle = AppSettings.shared.togglePairs.contains { $0.collapsed == t || $0.expanded == t }
            if isMyApp && (isToggleTitle || t == "⚡️" || t == "◀️" || t == "▶️") {
                arrowX = item.bounds.origin.x
                break
            }
        }
        
        // Fallback: search for separator "│"
        if arrowX == nil {
            for item in sortedItems {
                let isMyApp = (item.ownerName == myProcessName || item.ownerName == myAppName || item.ownerName == "BarCycle" || item.ownerName.contains("BarCycle"))
                let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if isMyApp && t == "│" {
                    arrowX = item.bounds.origin.x
                    break
                }
            }
        }
        
        // Fallback: search for any of our app's status items
        if arrowX == nil {
            for item in sortedItems {
                let isMyApp = (item.ownerName == myProcessName || item.ownerName == myAppName || item.ownerName == "BarCycle" || item.ownerName.contains("BarCycle"))
                if isMyApp {
                    arrowX = item.bounds.origin.x
                }
            }
        }
        
        // Filter: Keep only items on the left of the arrow, and exclude our app's own items
        var filteredItems = [StatusItemInfo]()
        for item in sortedItems {
            let isMyApp = (item.ownerName == myProcessName || item.ownerName == myAppName || item.ownerName == "BarCycle" || item.ownerName.contains("BarCycle"))
            let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let isToggleTitle = AppSettings.shared.togglePairs.contains { $0.collapsed == t || $0.expanded == t }
            let isAppIcon = isMyApp || isToggleTitle || t == "⚡️" || t == "◀️" || t == "▶️" || t == "│"
            
            if isAppIcon {
                continue
            }
            
            if let ax = arrowX {
                if item.bounds.origin.x < ax {
                    filteredItems.append(item)
                }
            } else {
                filteredItems.append(item)
            }
        }
        
        return filteredItems
    }
    
    /// Simulates a physical left click at the center coordinates of the status item
    func clickStatusItem(_ item: StatusItemInfo) {
        let centerX = item.bounds.origin.x + item.bounds.size.width / 2
        let centerY = item.bounds.origin.y + item.bounds.size.height / 2
        let point = CGPoint(x: centerX, y: centerY)
        
        print("Scanner: Clicking status item \(item.title) at point \(point)")
        
        // Attempt 1: Simulate mouse click (extremely reliable for all types of items)
        let source = CGEventSource(stateID: .combinedSessionState)
        
        let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        
        mouseDown?.post(tap: .cghidEventTap)
        // Wait 10ms between mouse down and up to simulate a real physical click
        // usleep(10000)
        mouseUp?.post(tap: .cghidEventTap)
    }
}
