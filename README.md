# BarCycle

> Alt-tab for the menu bar.

![Project icon](Resources/icon.png)


## Why this app

Other solutions either force you to:
- hide items: **less clutter** but **more struggle** to access
- keep items visible: **less struggle** to access but **more clutter**

With **BarCycle**, you keep items hidden but quicly accessible via ⌥ + tab:
- **hit** the shortcut
- **cycle** to your item (or input its index)
- **interact** with it
- it **hides** automatically

## Screenshots

The  ⌥ + tab shortcut in action:

![example](Resources/cycle.gif)

The settings for a bit of customization:

![settings](Resources/settings.png)

How to configure your items by zones (same as hiddenbar/ice...):

![help](Resources/help.png)

Average memory consumption:

![memory](Resources/memory.png)

## Features

- Keyboard-first item cycling
- 3 item zones (always hidden/collapsed/visible)
- Minimal memory (30mb only)
- Minimal customization

## Installation 

- Download latest dmg file from release
- Drag and drop the app into your applications folder

#### Bypass Gatekeeper on first launch

Because I don't have an Apple Developer account, you are going to get a warning. That's ok.

- Go to System Preferences > Security & Privacy > General
- Click "Open Anyway" for BarCycle.

> After that, you should be able to open the app without issues.

#### Build from source

If you build from source, you won't have to bypass Gatekeeper as the app will be signed with an ad-hoc signature!

- ```./build.sh```
- open the dmg file generated in the dist folder
- drag and drop the app into your applications folder

## Contributing

1. Fork the repository.
2. Create a branch for your change.
3. Run the project locally.
4. Open a pull request with a clear description.

#### Project Structure

- `BarCycleApp.swift` - app entry point
- `HUDWindow.swift` - HUD presentation
- `WindowScanner.swift` - window discovery
- `SettingsWindow.swift` - preferences UI
- `build.sh` - build helper


#### License

- This project is licensed under the MIT License.
