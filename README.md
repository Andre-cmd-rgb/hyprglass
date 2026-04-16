# hyprglass

A production-ready, modular Hyprland environment for fresh Arch Linux installs.

This repo is built as an actual shell, not a screenshot trap:
- modular Hyprland architecture
- floating glass-style Waybar with centered clock
- macOS-inspired UX cues without pretending to be macOS
- wallpaper-driven dynamic theming with `matugen`
- dock + launcher + notifications styled from one color pipeline
- minimal but complete package set
- no power-management logic
- no fixed color theme

## Design goals

- stable on a fresh Arch install
- readable and maintainable
- dark base with dynamic accents
- rounded corners everywhere possible
- blurred translucent surfaces instead of fake full transparency
- zero duplicated color definitions across components
- exact default monitor scale: **2x**

## Stack

Core shell:
- Hyprland
- Waybar
- Rofi
- Mako
- Kitty
- Thunar
- nwg-dock-hyprland

Dynamic theming:
- matugen
- hyprpaper

System:
- NetworkManager
- network-manager-applet
- ModemManager
- PipeWire + WirePlumber
- BlueZ

Utilities:
- tmux
- btop
- fastfetch
- cava

## Repository structure

```text
.
├── config
│   ├── btop
│   ├── cava
│   ├── fastfetch
│   ├── gtk-3.0
│   ├── gtk-4.0
│   ├── hypr
│   │   └── conf.d
│   ├── kitty
│   ├── mako
│   ├── rofi
│   ├── theme
│   │   ├── generated
│   │   └── matugen
│   │       └── templates
│   └── waybar
├── local
│   └── bin
├── install.sh
├── wallpapers
└── README.md
```


Repo directories are intentionally **not hidden** in GitHub:
- `config/` is deployed to `~/.config/`
- `local/bin/` is deployed to `~/.local/bin/`

That keeps the repository clean to browse on GitHub without changing the installed Linux paths.

## Architecture

### 1. Hyprland is orchestration, not a dump folder
`~/.config/hypr/hyprland.conf` only sources modular files:
- monitors
- environment
- input
- general
- decoration
- animations
- layout
- rules
- binds
- autostart

This keeps the compositor readable and lets you change one concern without touching unrelated parts.

### 2. Theme state is centralized
The theme pipeline is:

```text
wallpaper
  ↓
~/.local/bin/theme-apply
  ↓
matugen
  ↓
~/.config/theme/generated/*
  ↓
waybar / rofi / kitty / mako / gtk / dock
```

Canonical runtime theme state lives in:
- `~/.config/theme/current_wallpaper`
- `~/.config/theme/generated/colors.json`
- `~/.config/theme/generated/colors.css`

No component owns accent colors locally.

### 3. Autostart order is deliberate
Startup is structured so generated theme files exist before the shell UI depends on them:
1. import environment into systemd/dbus user session
2. start `hyprpaper`
3. generate the active theme from the current wallpaper
4. start Waybar
5. start Mako
6. start the polkit agent
7. start `nm-applet`
8. start the dock

### 4. Portals are explicit
Hyprland portal backend handles compositor-specific features like screen sharing and global shortcuts.
GTK portal backend handles file chooser, OpenURI and Print fallback.

## Installation

On a fresh Arch install:

```bash
git clone https://github.com/Andre-cmd-rgb/hyprglass.git
cd hyprglass
chmod +x install.sh
./install.sh
```

One-line install:

```bash
git clone https://github.com/Andre-cmd-rgb/hyprglass.git && cd hyprglass && chmod +x install.sh && ./install.sh
```

The installer:
- installs pacman packages
- bootstraps `yay`
- enables required services
- backs up existing config
- deploys the repo
- writes portal preferences
- generates the first theme from `wallpapers/default.png` when present, otherwise keeps the fallback generated theme files until you add a wallpaper

## Default wallpaper

This repo is designed to use your own default wallpaper.

Preferred repo path:

```text
wallpapers/default.png
```

If you do not include it before running the installer, the setup still installs cleanly.
You can add it later to:

```text
~/Pictures/Wallpapers/hyprglass/default.png
```

and then run:

```bash
~/.local/bin/theme-apply ~/Pictures/Wallpapers/hyprglass/default.png
```

## Keybindings

| Key | Action |
|---|---|
| `Super + Return` | Kitty |
| `Super + Space` | Spotlight-style Rofi launcher |
| `Super + E` | Thunar |
| `Super + D` | Toggle dock |
| `Super + Shift + D` | Toggle notification DND |
| `Super + Shift + W` | Random wallpaper + recolor |
| `Super + Shift + Q` | Close focused window |
| `Super + F` | Fullscreen |
| `Super + Shift + F` | Toggle floating |
| `Super + H/J/K/L` | Focus movement |
| `Super + Shift + H/J/K/L` | Move window |
| `Super + 1..0` | Workspace switch |
| `Super + Shift + 1..0` | Move window to workspace |

## Dynamic theming

Apply a specific wallpaper:

```bash
~/.local/bin/theme-apply /absolute/path/to/wallpaper.jpg
```

Pick a random wallpaper from your wallpaper directory:

```bash
~/.local/bin/theme-random
```

The script:
- stores the active wallpaper path
- regenerates the palette with `matugen`
- rewrites `hyprpaper.conf`
- reloads the running wallpaper through IPC when available
- refreshes Waybar
- reloads Mako
- pushes colors to running Kitty instances when possible
- restarts the dock so the CSS theme updates immediately

## Scaling

The default monitor scale is **2x**.

That is not a compromise. It is the exact requested default, and on a 4K panel it also has the practical advantage of being an integer scale.

If you want to change it later, edit:

```bash
~/.config/hypr/conf.d/00-monitors.conf
```

## GTK/macOS-style caveat

The traffic-light button styling is a best-effort approximation.
It works best on apps that honor GTK headerbar settings and CSS.
Some GTK/libadwaita apps may override parts of the decoration layout or their headerbar controls.
That is a Linux toolkit limitation, not a broken repo.

## Post-install customization

Safe places to edit:
- `~/.config/hypr/conf.d/00-monitors.conf` → monitor rules
- `~/.config/hypr/conf.d/50-animations.conf` → animation feel
- `~/.config/waybar/config.jsonc` → module layout
- `~/.config/rofi/theme.rasi` → launcher density
- `~/.config/theme/matugen/config.toml` → theme pipeline
- `~/.config/theme/matugen/templates/*` → generated theme outputs

Avoid hardcoding colors into component configs.
If you do that, you break the architecture.

## Validation checklist

After install, verify:
- `Hyprland` starts cleanly
- `waybar`, `mako`, `hyprpaper`, `nm-applet`, and `nwg-dock-hyprland` start
- `xdg-desktop-portal-hyprland` and `xdg-desktop-portal-gtk` activate on demand
- `Super + Space` opens Rofi
- `theme-apply` regenerates colors and wallpaper
- Dock styling updates after a wallpaper change
- Bluetooth, audio, network, and LTE services are enabled

## License

MIT


## final notes

- default display scaling is 2x.
- Bluetooth GUI integration uses blueman-applet and blueman-manager.
- dock toggling now uses the resident dock signal path when available, instead of always killing the process.
- fallback generated theme files are included so Waybar, Rofi, Kitty and the dock look coherent on first launch before you swap wallpapers.
