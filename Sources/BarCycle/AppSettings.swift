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

enum AutoCollapseDelay: Double, CaseIterable, Identifiable {
    case zero = 0.0
    case one = 1.0
    case three = 3.0
    case five = 5.0
    case ten = 10.0
    case thirty = 30.0
    case oneMinute = 60.0
    case never = -1.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .zero: return "0s"
        case .one: return "1s"
        case .three: return "3s"
        case .five: return "5s"
        case .ten: return "10s"
        case .thirty: return "30s"
        case .oneMinute: return "1min"
        case .never: return "Never"
        }
    }

    static func from(double: Double) -> AutoCollapseDelay {
        return allCases.min(by: { abs($0.rawValue - double) < abs($1.rawValue - double) }) ?? .never
    }
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
    
    // Auto-collapse delay when using the HUD (Option+Tab)
    // -1 means never
    var hudAutoCollapseDelay: AutoCollapseDelay {
        get {
            if UserDefaults.standard.object(forKey: "BarCycle_HudAutoCollapseDelay") == nil {
                return .zero // Default 0s for HUD (instant collapse after action)
            }
            let doubleVal = UserDefaults.standard.double(forKey: "BarCycle_HudAutoCollapseDelay")
            return AutoCollapseDelay.from(double: doubleVal)
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "BarCycle_HudAutoCollapseDelay")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    // Auto-collapse delay when manually clicking the toggle arrow
    // -1 means never
    var manualAutoCollapseDelay: AutoCollapseDelay {
        get {
            if UserDefaults.standard.object(forKey: "BarCycle_ManualAutoCollapseDelay") == nil {
                return .never // Default never for manual clicks
            }
            let doubleVal = UserDefaults.standard.double(forKey: "BarCycle_ManualAutoCollapseDelay")
            return AutoCollapseDelay.from(double: doubleVal)
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "BarCycle_ManualAutoCollapseDelay")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
}

