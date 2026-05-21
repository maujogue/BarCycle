import Cocoa

class ColorPresetButton: NSButton {
    let presetColor: NSColor
    
    init(color: NSColor) {
        self.presetColor = color
        super.init(frame: .zero)
        self.title = ""
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.backgroundColor = color.cgColor
        self.layer?.cornerRadius = 12
        self.layer?.borderWidth = 1.5
        self.layer?.borderColor = NSColor(white: 0.5, alpha: 0.3).cgColor
        
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 24),
            heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TogglePairButton: NSButton {
    let pairIndex: Int
    
    init(pair: (collapsed: String, expanded: String), index: Int) {
        self.pairIndex = index
        super.init(frame: .zero)
        self.title = "\(pair.collapsed)  \(pair.expanded)"
        self.bezelStyle = .recessed
        self.font = NSFont.systemFont(ofSize: 14)
        self.isBordered = true
        
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 90),
            heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SettingsWindow: NSWindow {
    static let shared = SettingsWindow()
    
    private let bgColorWell = NSColorWell()
    private let textColorWell = NSColorWell()
    private var presetBgButtons = [ColorPresetButton]()
    private var presetTextButtons = [ColorPresetButton]()
    private var toggleButtons = [TogglePairButton]()
    
    private init() {
        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 480)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.title = "BarCycle Preferences"
        self.isReleasedWhenClosed = false
        self.center()
        
        setupUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsChanged), name: .settingsChanged, object: nil)
    }
    
    private func setupUI() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = container
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: stackView.topAnchor),
            container.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
        ])

        let titleLabel = NSTextField(labelWithString: "BarCycle Preferences")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        stackView.addArrangedSubview(titleLabel)
        stackView.setCustomSpacing(20, after: titleLabel)

        let bgSectionLabel = NSTextField(labelWithString: "Circle Background (Unselected)")
        bgSectionLabel.font = NSFont.boldSystemFont(ofSize: 12)
        bgSectionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(bgSectionLabel)

        let bgRow = NSStackView()
        bgRow.orientation = .horizontal
        bgRow.spacing = 8
        bgRow.alignment = .centerY

        let bgPresets = [
            NSColor(red: 20.586/255.0, green: 24.173/255.0, blue: 234.14/255.0, alpha: 1.0),
            NSColor(red: 0.31, green: 0.32, blue: 0.35, alpha: 1.0),
            NSColor(red: 1.0, green: 0.70, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.15, green: 0.20, blue: 0.45, alpha: 1.0),
            NSColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1.0),
            .black
        ]

        for color in bgPresets {
            let button = ColorPresetButton(color: color)
            button.target = self
            button.action = #selector(bgPresetClicked(_:))
            presetBgButtons.append(button)
            bgRow.addArrangedSubview(button)
        }

        let bgCustomLabel = NSTextField(labelWithString: "Custom:")
        bgCustomLabel.font = NSFont.systemFont(ofSize: 11)
        bgRow.addArrangedSubview(bgCustomLabel)

        bgColorWell.translatesAutoresizingMaskIntoConstraints = false
        bgColorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        bgColorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true
        bgColorWell.target = self
        bgColorWell.action = #selector(bgCustomColorChanged(_:))
        bgRow.addArrangedSubview(bgColorWell)

        stackView.addArrangedSubview(bgRow)
        stackView.setCustomSpacing(20, after: bgRow)

        let textSectionLabel = NSTextField(labelWithString: "Number / Text Color (Unselected)")
        textSectionLabel.font = NSFont.boldSystemFont(ofSize: 12)
        textSectionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(textSectionLabel)

        let textRow = NSStackView()
        textRow.orientation = .horizontal
        textRow.spacing = 8
        textRow.alignment = .centerY

        let textPresets = [
            NSColor.white,
            NSColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0),
            NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        ]

        for color in textPresets {
            let button = ColorPresetButton(color: color)
            button.target = self
            button.action = #selector(textPresetClicked(_:))
            presetTextButtons.append(button)
            textRow.addArrangedSubview(button)
        }

        let textCustomLabel = NSTextField(labelWithString: "Custom:")
        textCustomLabel.font = NSFont.systemFont(ofSize: 11)
        textRow.addArrangedSubview(textCustomLabel)

        textColorWell.translatesAutoresizingMaskIntoConstraints = false
        textColorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        textColorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true
        textColorWell.target = self
        textColorWell.action = #selector(textCustomColorChanged(_:))
        textRow.addArrangedSubview(textColorWell)

        stackView.addArrangedSubview(textRow)
        stackView.setCustomSpacing(24, after: textRow)

        let iconSectionLabel = NSTextField(labelWithString: "Menu Bar Toggle Icons (Collapsed / Expanded)")
        iconSectionLabel.font = NSFont.boldSystemFont(ofSize: 12)
        iconSectionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(iconSectionLabel)

        let iconGrid = NSStackView()
        iconGrid.orientation = .vertical
        iconGrid.spacing = 8
        iconGrid.alignment = .leading

        let row1 = NSStackView()
        row1.orientation = .horizontal
        row1.spacing = 8

        let row2 = NSStackView()
        row2.orientation = .horizontal
        row2.spacing = 8

        let row3 = NSStackView()
        row3.orientation = .horizontal
        row3.spacing = 8

        for (index, pair) in AppSettings.shared.togglePairs.enumerated() {
            let button = TogglePairButton(pair: pair, index: index)
            button.target = self
            button.action = #selector(togglePairClicked(_:))
            toggleButtons.append(button)
            
            if index < 3 {
                row1.addArrangedSubview(button)
            } else if index < 6 {
                row2.addArrangedSubview(button)
            } else {
                row3.addArrangedSubview(button)
            }
        }

        iconGrid.addArrangedSubview(row1)
        iconGrid.addArrangedSubview(row2)
        iconGrid.addArrangedSubview(row3)
        stackView.addArrangedSubview(iconGrid)

        updateColorWellValues()
        updateHighlightStates()
    }
    
    private func updateColorWellValues() {
        bgColorWell.color = AppSettings.shared.unselectedBgColor
        textColorWell.color = AppSettings.shared.unselectedTextColor
    }
    
    private func updateHighlightStates() {
        let currentBgHex = AppSettings.shared.unselectedBgColor.toHex()
        for button in presetBgButtons {
            let isCurrent = button.presetColor.toHex() == currentBgHex
            button.layer?.borderColor = isCurrent ? NSColor.controlAccentColor.cgColor : NSColor(white: 0.5, alpha: 0.3).cgColor
            button.layer?.borderWidth = isCurrent ? 2.5 : 1.5
        }
        
        let currentTextHex = AppSettings.shared.unselectedTextColor.toHex()
        for button in presetTextButtons {
            let isCurrent = button.presetColor.toHex() == currentTextHex
            button.layer?.borderColor = isCurrent ? NSColor.controlAccentColor.cgColor : NSColor(white: 0.5, alpha: 0.3).cgColor
            button.layer?.borderWidth = isCurrent ? 2.5 : 1.5
        }
        
        let currentToggleIndex = AppSettings.shared.togglePairIndex
        for button in toggleButtons {
            let isCurrent = button.pairIndex == currentToggleIndex
            button.state = isCurrent ? .on : .off
        }
    }
    
    @objc private func onSettingsChanged() {
        updateColorWellValues()
        updateHighlightStates()
    }
    
    @objc private func bgPresetClicked(_ sender: ColorPresetButton) {
        AppSettings.shared.unselectedBgColor = sender.presetColor
    }
    
    @objc private func bgCustomColorChanged(_ sender: NSColorWell) {
        AppSettings.shared.unselectedBgColor = sender.color
    }
    
    @objc private func textPresetClicked(_ sender: ColorPresetButton) {
        AppSettings.shared.unselectedTextColor = sender.presetColor
    }
    
    @objc private func textCustomColorChanged(_ sender: NSColorWell) {
        AppSettings.shared.unselectedTextColor = sender.color
    }
    
    @objc private func togglePairClicked(_ sender: TogglePairButton) {
        AppSettings.shared.togglePairIndex = sender.pairIndex
    }
}
