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
        
        if !isGeneric {
            return cleanedTitle
        }
        
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
        
        return ownerName
    }
    
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
            
            var title = window[kCGWindowName as String] as? String ?? ""
            var desc = ""
            var axElement: AXUIElement?
            
            if let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 {
                let appElement = AXUIElementCreateApplication(ownerPID)
                var axItems = [AXUIElement]()
                findMenuBarItems(in: appElement, items: &axItems)
                
                for element in axItems {
                    if let frame = getElementFrame(element) {
                        let rectCenter = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
                        let frameCenter = CGPoint(x: frame.origin.x + frame.size.width / 2, y: frame.origin.y + frame.size.height / 2)
                        let dist = hypot(rectCenter.x - frameCenter.x, rectCenter.y - frameCenter.y)
                        
                        if dist < 15 {
                            axElement = element
                            break
                        }
                    }
                }
            }
            
            if axElement == nil {
                let centerX = rect.origin.x + rect.size.width / 2
                let centerY = rect.origin.y + rect.size.height / 2
                var hitElement: AXUIElement?
                let axStatus = AXUIElementCopyElementAtPosition(systemWide, Float(centerX), Float(centerY), &hitElement)
                if axStatus == .success, let element = hitElement {
                    axElement = element
                }
            }
            
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
                
                if title.isEmpty {
                    var axRoleDesc: AnyObject?
                    AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &axRoleDesc)
                    if let rd = axRoleDesc as? String {
                        title = rd
                    }
                }
            }
            
            let finalTitle = cleanTitle(title: title, desc: desc, ownerName: ownerName)
            
            if desc.isEmpty {
                desc = "Status item for \(ownerName)"
            }
            
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
        
        let sortedItems = items.sorted(by: { $0.bounds.origin.x < $1.bounds.origin.x })
        
        let myProcessName = ProcessInfo.processInfo.processName
        let myAppName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "BarCycle"
        
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
        
        if arrowX == nil {
            for item in sortedItems {
                let isMyApp = (item.ownerName == myProcessName || item.ownerName == myAppName || item.ownerName == "BarCycle" || item.ownerName.contains("BarCycle"))
                if isMyApp {
                    arrowX = item.bounds.origin.x
                }
            }
        }
        
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
    
    func clickStatusItem(_ item: StatusItemInfo) {
        let centerX = item.bounds.origin.x + item.bounds.size.width / 2
        let centerY = item.bounds.origin.y + item.bounds.size.height / 2
        let point = CGPoint(x: centerX, y: centerY)
        
        print("Scanner: Clicking status item \(item.title) at point \(point)")
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
}
