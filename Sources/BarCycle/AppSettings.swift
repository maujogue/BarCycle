import Cocoa
import ServiceManagement

extension NSColor {
    func toHex() -> String? {
        guard let rgbColor = usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("BarCycle_SettingsChanged")
    static let settingsWindowVisibilityChanged = Notification.Name("BarCycle_SettingsWindowVisibilityChanged")
}

class AppSettings {
    static let shared = AppSettings()
    
    private let unselectedBgKey = "BarCycle_UnselectedBgHex"
    private let unselectedTextKey = "BarCycle_UnselectedTextHex"
    private let togglePairIndexKey = "BarCycle_TogglePairIndex"
    
    let togglePairs: [(collapsed: String, expanded: String)] = [
        ("‹", "›"),   // Sleek Chevrons
        ("◀", "▶"),   // Solid Triangles
        ("○", "●"),   // Minimalist Dots
        ("⚡️", "💤"), // Lightning / Sleep Emojis
        ("👁️", "🙈"), // Eye / Monkey Emojis
        ("🟢", "🔴 ")  // Green / Red Emojis
    ]

    
    private init() {}
    
    var unselectedBgColor: NSColor {
        get {
            if let hex = UserDefaults.standard.string(forKey: unselectedBgKey), let color = NSColor(hex: hex) {
                return color
            }
            // Default: electric blue rgb(20.586, 24.173, 234.14)
            return NSColor(red: 20.586 / 255.0, green: 24.173 / 255.0, blue: 234.14 / 255.0, alpha: 1.0)
        }
        set {
            UserDefaults.standard.set(newValue.toHex(), forKey: unselectedBgKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    var unselectedTextColor: NSColor {
        get {
            if let hex = UserDefaults.standard.string(forKey: unselectedTextKey), let color = NSColor(hex: hex) {
                return color
            }
            // Default: white
            return .white
        }
        set {
            UserDefaults.standard.set(newValue.toHex(), forKey: unselectedTextKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    var togglePairIndex: Int {
        get {
            return UserDefaults.standard.integer(forKey: togglePairIndexKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: togglePairIndexKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    var launchAtLogin: Bool {
        get {
            return SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("BarCycle: Failed to update Launch at Login: \(error)")
            }
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var currentTogglePair: (collapsed: String, expanded: String) {
        let index = togglePairIndex
        if index >= 0 && index < togglePairs.count {
            return togglePairs[index]
        }
        return togglePairs[0]
    }
}

