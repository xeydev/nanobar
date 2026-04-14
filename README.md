# NanoBar

A lightweight, plugin-based status bar for macOS built with Swift and SwiftUI. Designed as a fast, native alternative to macOS topbar.

> **Requires macOS 15 (Sequoia) or later**

---

## Features

- **Native performance** — pure Swift/SwiftUI, no shell scripts on the hot path
- **Plugin system** — extend with `.bundle` plugins; hot-reload config without restart
- **TOML config** — human-readable, watched for changes at `~/.config/nanobar/config.toml`
- **Glassmorphic pills** — per-widget vibrancy materials, borders, shadows, corner radii
- **Multi-monitor** — one bar per screen, automatically managed
- **Fullscreen aware** — bar hides when a fullscreen window covers the screen
- **AeroSpace integration** — workspace indicator with socket-based live updates
- **Mouse pass-through** — clicks fall through to windows except on interactive widgets

## Installation

### From source

```bash
git clone https://github.com/your-username/nanobar
cd nanobar
./install.sh
```

`install.sh` will:
1. Build a release binary with `swift build -c release`
2. Install it to `/usr/local/bin/nanobar`
3. Install a LaunchAgent (`com.user.nanobar.plist`) and start it
4. Patch `~/.aerospace.toml` if AeroSpace is detected

Logs are written to `/tmp/nanobar.log` and `/tmp/nanobar.err`.


## Configuration

NanoBar reads `~/.config/nanobar/config.toml` and hot-reloads on change.

A minimal config is created automatically on first launch. Full reference:

```toml
[widgets]
left   = ["workspaces"]
center = ["now_playing"]
right  = ["keyboard", "volume", "battery", "clock"]

# ─── Bar appearance ───────────────────────────────────────────────────────────

[bar]
background   = "none"    # none | blur | color:#RRGGBBAA
height       = 30
cornerRadius = 0
shadow       = false

# Gap between screen edge and bar — scalar or per-side table
margin  = 0
# margin = { all = 6, top = 4, bottom = 4 }

# Gap between bar edge and pill widgets
padding = 8
# padding = { all = 8, left = 12, right = 12 }

# Border: false | true | { width = 1.0, color = "#FFFFFF59" }
border  = false

# ─── Pill appearance ──────────────────────────────────────────────────────────

[pill]
shadow       = true
border       = true
material     = "glass"   # glass | thin | ultraThin | solid | none
specular     = true
cornerRadius = 15

# ─── Plugins ──────────────────────────────────────────────────────────────────

[plugins.clock]
bundle = "/path/to/ClockPlugin.bundle"
format = "EEE dd MMM HH:mm"
color  = "#FF7EB6"

[plugins.battery]
bundle    = "/path/to/BatteryPlugin.bundle"
color     = "#B5EAD7"
warnColor = "#FFD1A8"
medColor  = "#FEFAC1"
lowColor  = "#FFB3BF"

[plugins.volume]
bundle = "/path/to/VolumePlugin.bundle"
color  = "#AEC6CF"

[plugins.keyboard]
bundle = "/path/to/KeyboardPlugin.bundle"
color  = "#DDB6F2"

[plugins.workspaces]
bundle = "/path/to/AeroSpacePlugin.bundle"
mode   = "clampAndExpand"  # labelsOnly | activeIcons | clampAndExpand

[plugins.now_playing]
bundle      = "/path/to/SpotifyPlugin.bundle"
activeColor = "#B5EAD7"
```

### Per-plugin pill overrides

Each plugin section can contain a `[plugins.<id>.pill]` subtable that overrides the global `[pill]` for that widget:

```toml
[plugins.clock.pill]
cornerRadius = 20
border       = { width = 1.0, color = "#FF7EB6" }
material     = "ultraThin"
```

### Margins and padding

Both `margin` and `padding` accept a scalar (all sides) or an inline table with optional per-side keys:

```toml
margin = 6                              # all sides = 6
margin = { all = 6, top = 4 }          # default 6, override top = 4
padding = { all = 8, left = 16 }       # default 8, left = 16
```

## Built-in Plugins

| Plugin | Bundle | Key settings |
|---|---|---|
| **Clock** | `ClockPlugin.bundle` | `format` (date format string), `color` |
| **Battery** | `BatteryPlugin.bundle` | `color`, `warnColor`, `medColor`, `lowColor` |
| **Volume** | `VolumePlugin.bundle` | `color` |
| **Keyboard** | `KeyboardPlugin.bundle` | `color` |
| **AeroSpace workspaces** | `AeroSpacePlugin.bundle` | `mode` (`labelsOnly` \| `activeIcons` \| `clampAndExpand`) |
| **Spotify / Now Playing** | `SpotifyPlugin.bundle` | `activeColor` |
| **Tmux** | `TmuxPlugin.bundle` | — |

### Building plugins

Each plugin lives in `Plugins/<Name>Plugin/` as a Swift package:

```bash
cd Plugins/ClockPlugin
./build.sh   # prints the absolute path to the built .bundle
```

Copy the printed path into your config's `bundle` key.

## Writing a Plugin

Plugins are macOS `.bundle` targets that implement the `NanoBarPluginAPI` protocol over Objective-C ABI for binary stability across Swift versions.

### 1. Declare the entry point

In `Info.plist`, set `NSPrincipalClass` to your entry class name.

```swift
import NanoBarPluginAPI
import AppKit

@objc(MyPluginEntry)
final class MyPluginEntry: NSObject, NanoBarPluginEntry {
    func registerWidgets(with registry: NanoBarWidgetRegistry,
                         config: NanoBarConfig) {
        registry.register(MyWidgetFactory(config: config))
    }
}
```

### 2. Implement a widget factory

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

### 3. Build as a bundle

In `Package.swift`, target type must be `.plugin` (or a dynamic library wrapped as a bundle). See existing plugins for the canonical setup.

### Config key forwarding

Every key in `[plugins.<id>]` other than `bundle` and `pill` is forwarded to the plugin as `[String: String]`. Plugins access them via `config.settings(for:)`. Type coercion and validation is the plugin's responsibility.

## AeroSpace Integration

The AeroSpace workspace plugin listens on a Unix socket at `/tmp/nanobar-notify.sock`. Add this to `~/.aerospace.toml`:

```toml
exec-on-workspace-change = ['/bin/bash', '-c',
  'printf "%s" "$AEROSPACE_FOCUSED_WORKSPACE" | nc -U /tmp/nanobar-notify.sock']
```

`install.sh` patches this automatically when it detects AeroSpace.

## Uninstalling

```bash
launchctl unload ~/Library/LaunchAgents/com.user.nanobar.plist
rm ~/Library/LaunchAgents/com.user.nanobar.plist
sudo rm /usr/local/bin/nanobar
rm -rf ~/.config/nanobar   # optional — removes your config
```

## License

MIT
