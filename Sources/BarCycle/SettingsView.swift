import SwiftUI
import AppKit

// MARK: - Sections

enum SettingsSection: Int, CaseIterable, Identifiable {
    case howToUse, settings, support, about
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .howToUse: return "How to Use"
        case .settings: return "Settings"
        case .support:  return "Support"
        case .about:    return "About"
        }
    }

    var symbol: String {
        switch self {
        case .howToUse: return "questionmark.circle"
        case .settings: return "gearshape"
        case .support:  return "lifepreserver"
        case .about:    return "info.circle"
        }
    }
}

// MARK: - Store (bridges SwiftUI <-> AppSettings.shared)

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var bgColor: Color
    @Published var textColor: Color
    @Published var toggleIndex: Int
    @Published var launchAtLogin: Bool

    private var observer: NSObjectProtocol?

    private init() {
        self.bgColor = Color(nsColor: AppSettings.shared.unselectedBgColor)
        self.textColor = Color(nsColor: AppSettings.shared.unselectedTextColor)
        self.toggleIndex = AppSettings.shared.togglePairIndex
        self.launchAtLogin = AppSettings.shared.launchAtLogin

        observer = NotificationCenter.default.addObserver(
            forName: .settingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.bgColor = Color(nsColor: AppSettings.shared.unselectedBgColor)
                self.textColor = Color(nsColor: AppSettings.shared.unselectedTextColor)
                self.toggleIndex = AppSettings.shared.togglePairIndex
                self.launchAtLogin = AppSettings.shared.launchAtLogin
            }
        }
    }

    func setBg(_ ns: NSColor)   { AppSettings.shared.unselectedBgColor = ns }
    func setText(_ ns: NSColor) { AppSettings.shared.unselectedTextColor = ns }
    func setToggle(_ i: Int)    { AppSettings.shared.togglePairIndex = i }
    func setLaunchAtLogin(_ b: Bool) { AppSettings.shared.launchAtLogin = b }
}

// MARK: - Root

struct SettingsRootView: View {
    @State private var selection: SettingsSection = .howToUse

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { sec in
                Label(sec.title, systemImage: sec.symbol)
                    .tag(sec)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch selection {
                case .howToUse: HowToUseView()
                case .settings: SettingsContentView()
                case .support:  SupportView()
                case .about:    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 940, minHeight: 640)
    }
}

// MARK: - How to Use

struct HowToUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("How to Use")
                    .font(.system(size: 26, weight: .bold))

                Text("BarCycle splits your menu bar into three zones using two dividers.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

				Text("⌘-drag your existing menu bar icons across the dividers to choose which ones always show, which appear only when you toggle, and which stay hidden.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let img = NSImage.barCycleHelp() {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 14) {
                    bullet("Hold ⌘ (Command) and drag the menu bar separators to move your apps between the three zones.")
                    bullet("Click the BarCycle toggle (chevron / arrow) in the menu bar to collapse or expand the middle zone.")
                    bullet("Press ⌥ (Option) + Tab anywhere to summon the HUD and cycle through windows.")
                    bullet("Pick the collapsed / expanded glyph and circle colors in the Settings tab.")
                }
                .font(.system(size: 13))
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•").foregroundStyle(.secondary)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Settings

struct SettingsContentView: View {
    @ObservedObject private var store = SettingsStore.shared

    private let bgPresets: [NSColor] = [
        NSColor(red: 20.586/255.0, green: 24.173/255.0, blue: 234.14/255.0, alpha: 1.0),
        NSColor(red: 0.31, green: 0.32, blue: 0.35, alpha: 1.0),
        NSColor(red: 1.0, green: 0.70, blue: 0.0, alpha: 1.0),
        NSColor(red: 0.15, green: 0.20, blue: 0.45, alpha: 1.0),
        NSColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1.0),
        .black
    ]

    private let textPresets: [NSColor] = [
        .white,
        NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 26, weight: .bold))

                sectionHeader("Circle Background (Unselected)")
                HStack(spacing: 10) {
                    ForEach(Array(bgPresets.enumerated()), id: \.offset) { _, color in
                        PresetSwatch(color: color, isSelected: matches(color, store.bgColor)) {
                            store.setBg(color)
                        }
                    }
                    Text("Custom:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                    ColorPicker("", selection: Binding(
                        get: { store.bgColor },
                        set: { store.setBg(NSColor($0)) }
                    ))
                    .labelsHidden()
                }

                sectionHeader("Number / Text Color (Unselected)")
                HStack(spacing: 10) {
                    ForEach(Array(textPresets.enumerated()), id: \.offset) { _, color in
                        PresetSwatch(color: color, isSelected: matches(color, store.textColor)) {
                            store.setText(color)
                        }
                    }
                    Text("Custom:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                    ColorPicker("", selection: Binding(
                        get: { store.textColor },
                        set: { store.setText(NSColor($0)) }
                    ))
                    .labelsHidden()
                }

                sectionHeader("Menu Bar Toggle Icons (Collapsed / Expanded)")
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(Array(AppSettings.shared.togglePairs.enumerated()), id: \.offset) { idx, pair in
                        let isSelected = store.toggleIndex == idx
                        Button {
                            store.setToggle(idx)
                        } label: {
                            Text("\(pair.collapsed)   \(pair.expanded)")
                                .font(.system(size: 15))
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.bordered)
                        .tint(isSelected ? .accentColor : .secondary)
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func matches(_ ns: NSColor, _ swift: Color) -> Bool {
        ns.toHex() == NSColor(swift).toHex()
    }
}

private struct PresetSwatch: View {
    let color: NSColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: color))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle().stroke(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                        lineWidth: isSelected ? 2.5 : 1.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Support

struct SupportView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var accessibilityTrusted: Bool = AXIsProcessTrusted()

    private let pollTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "BarCycle \(version) (build \(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Support")
                    .font(.system(size: 26, weight: .bold))

                VStack(alignment: .leading, spacing: 8) {
                    header("Permissions")
                    if accessibilityTrusted {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Accessibility access granted")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 16, weight: .semibold))
                            Text("BarCycle needs Accessibility access to drive your menu bar. If icons stop responding, re-grant the permission in System Settings.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button("Open Accessibility Settings…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.large)
                        .padding(.top, 4)
                    }
                }
                .onReceive(pollTimer) { _ in
                    let now = AXIsProcessTrusted()
                    if now != accessibilityTrusted { accessibilityTrusted = now }
                }

                VStack(alignment: .leading, spacing: 8) {
                    header("Startup")
                    Toggle("Start at login", isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { store.setLaunchAtLogin($0) }
                    ))
                }

                VStack(alignment: .leading, spacing: 8) {
                    header("Version")
                    Text(versionString).foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("About BarCycle")
                    .font(.system(size: 26, weight: .bold))

                HStack(alignment: .center, spacing: 16) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 96, height: 96)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BarCycle").font(.system(size: 18, weight: .semibold))
                        Text("Made to solve my own issues! Hope it helps.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider().padding(.vertical, 8)

                Text("Find me")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: "https://www.linkedin.com/in/mathis-aujogue/")!) {
                    Label("LinkedIn — linkedin.com/in/mathis-aujogue", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/maujogue")!) {
                    Label("GitHub — github.com/maujogue", systemImage: "link")
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Image helpers

extension NSImage {
    static func barCycleHelp() -> NSImage? {
        if let img = NSImage(named: "help") { return img }
        if let url = Bundle.main.url(forResource: "help", withExtension: "png"),
           let img = NSImage(contentsOf: url) { return img }
        let bundleHelp = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/help.png")
        if let img = NSImage(contentsOf: bundleHelp) { return img }
        return nil
    }
}
