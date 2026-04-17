# NanoBar

A lightweight, plugin-based status bar for macOS — pure Swift/SwiftUI, no Electron, no shell scripts on the hot path.

**Requires macOS 15 (Sequoia) or later**

![NanoBar screenshot](docs/screenshot.png)

---

## What it looks like

| Default layout                          | Glassmorphic pills                  | AeroSpace workspaces                          |
| --------------------------------------- | ----------------------------------- | --------------------------------------------- |
| ![Default](docs/screenshot-default.png) | ![Pills](docs/screenshot-pills.png) | ![Workspaces](docs/screenshot-workspaces.png) |

---

## Features

- **Glassmorphic pills** — per-widget vibrancy materials, borders, shadows, corner radii
- **Plugin system** — extend with `.bundle` plugins; drop in or point to a path
- **Multi-monitor** — one bar per screen, automatically managed
- **Fullscreen aware** — bar hides when a fullscreen window covers the screen
- **AeroSpace integration** — workspace indicator with socket-based live updates
- **Native performance** — ~2% CPU at idle

---

## Installation

### Homebrew (recommended)

```bash
brew tap xeydev/tap
brew install nanobar
brew services start nanobar
```

### From source

```bash
git clone https://github.com/xeydev/nanobar
cd nanobar
bash build-release.sh
```

Produces a `dist/` directory with `bin/nanobar`, `libexec/NanoBar`, `libexec/NowPlayingHelper`, and all plugin bundles under `libexec/Plugins/`. Add `dist/bin` to your `PATH` or copy the contents to your preferred prefix.

Logs: `/tmp/nanobar.log` and `/tmp/nanobar.err`.

---

## Configuration

Config lives at `~/.config/nanobar/config.toml` and is created automatically on first launch.

```toml
[widgets]
left   = ["workspaces"]
center = ["now_playing"]
right  = ["keyboard", "volume", "battery", "clock"]
```

That's all you need to get started. Everything else is optional.

### Bar appearance

```toml
[bar]
background   = "none"    # none | blur | color:#RRGGBBAA
height       = 30
cornerRadius = 0
shadow       = false
margin       = 0         # gap between screen edge and bar
padding      = 8         # gap between bar edge and pill widgets
border       = false
```

`margin` and `padding` accept a scalar (all sides) or a per-side table:

```toml
margin  = { all = 6, top = 4 }
padding = { all = 8, left = 16 }
```

### Pill appearance

```toml
[pill]
shadow       = true
border       = true
material     = "glass"   # glass | thin | ultraThin | solid | none
specular     = true
cornerRadius = 15
```

Override per-plugin:

```toml
[plugins.clock.pill]
cornerRadius = 20
border       = { width = 1.0, color = "#FF7EB6" }
material     = "ultraThin"
```

---

## Built-in Plugins

All bundled plugins are auto-discovered at startup — no `bundle` key required.

| Plugin                    | Widget ID     | Settings                                                  |
| ------------------------- | ------------- | --------------------------------------------------------- |
| **Clock**                 | `clock`       | `format` (date format string), `color`                    |
| **Battery**               | `battery`     | `color`, `warnColor`, `medColor`, `lowColor`              |
| **Volume**                | `volume`      | `color`                                                   |
| **Keyboard layout**       | `keyboard`    | `color`                                                   |
| **AeroSpace workspaces**  | `workspaces`  | `mode`: `labelsOnly` \| `activeIcons` \| `clampAndExpand` |
| **Spotify / Now Playing** | `now_playing` | `activeColor`                                             |
| **Tmux session**          | `tmux`        | —                                                         |

Example plugin config:

```toml
[plugins.clock]
format = "EEE dd MMM HH:mm"
color  = "#FF7EB6"

[plugins.battery]
color     = "#B5EAD7"
warnColor = "#FFD1A8"
medColor  = "#FEFAC1"
lowColor  = "#FFB3BF"

[plugins.volume]
color = "#AEC6CF"

[plugins.keyboard]
color = "#DDB6F2"

[plugins.workspaces]
mode = "clampAndExpand"

[plugins.now_playing]
activeColor = "#B5EAD7"
```

---

## AeroSpace Integration

The workspaces plugin listens on a Unix socket. Add this to `~/.aerospace.toml`:

```toml
exec-on-workspace-change = ['/bin/bash', '-c',
  'printf "%s" "$AEROSPACE_FOCUSED_WORKSPACE" | nc -U /tmp/nanobar-notify.sock']
```

Add this manually to `~/.aerospace.toml`.

---

## Writing a Plugin

Plugins are macOS `.bundle` targets implementing the `NanoBarPluginAPI` protocol.

### 1. Entry point

Set `NSPrincipalClass` in `Info.plist` to your entry class name, then implement:

```swift
import NanoBarPluginAPI

@objc(MyPluginEntry)
final class MyPluginEntry: NSObject, NanoBarPluginEntry {
    func registerWidgets(with registry: NanoBarWidgetRegistry,
                         config: NanoBarConfig) {
        registry.register(MyWidgetFactory(config: config))
    }
}
```

### 2. Widget factory

```swift
import NanoBarPluginAPI
import SwiftUI

final class MyWidgetFactory: NSObject, NanoBarWidgetFactory {
    let widgetID = "my_widget"   // matches [plugins.my_widget] in config
    private let settings: [String: String]

    init(config: NanoBarConfig) {
        self.settings = config.settings(for: "my_widget")
    }

    func makeViewBox() -> NanoBarViewBox {
        NanoBarViewBoxImpl(AnyView(MyWidgetView(settings: settings)))
    }
}
```

### 3. Build

Declare a `.target` with `type: .dynamic` in `Package.swift`. See existing plugins for the canonical setup.

```bash
cd Plugins/MyPlugin
./build.sh   # prints the path to the built .bundle
```

Point to it from config:

```toml
[plugins.my_widget]
bundle = "/path/to/MyPlugin.bundle"
```

Every key in `[plugins.<id>]` other than `bundle` and `pill` is forwarded to the plugin as `[String: String]` via `config.settings(for:)`.

---

## Uninstalling

```bash
launchctl unload ~/Library/LaunchAgents/com.user.nanobar.plist
rm ~/Library/LaunchAgents/com.user.nanobar.plist
sudo rm /usr/local/bin/nanobar
rm -rf ~/.config/nanobar   # optional — removes your config
```
