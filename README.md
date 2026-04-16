# hyprglass

**hyprglass** is a release-oriented Hyprland environment for Arch Linux: dark, clean, glassy, modular, and daily-drivable.

This is not a personal dump of random dotfiles. It is a productized shell layout with a scoped installer, centralized theme pipeline, explicit NVIDIA handling, and a repository structure meant to be published and maintained.

## Design goals

- **Arch-first** and explicit about it
- **Hyprland-first**, no compositor abstraction layer
- **Dark base + wallpaper-driven accents**
- **Glassy shell surfaces without fake full transparency**
- **Safe, scoped install behavior**
- **Minimal stack, no pointless AUR dependency chain**
- **Readable repo and maintainable scripts**

## Core stack

### Shell
- Hyprland
- Hyprpaper
- Waybar
- Rofi
- Mako
- Kitty
- Thunar

### Theming
- matugen for palette/template generation only
- hyprpaper as the actual wallpaper owner
- `theme-apply` as the runtime glue script

### System integration
- NetworkManager
- ModemManager
- PipeWire + WirePlumber
- BlueZ + Blueman
- xdg-desktop-portal-hyprland + xdg-desktop-portal-gtk
- hyprpolkitagent
- greetd + gtkgreet

### Utilities
- tmux
- btop
- fastfetch
- cava

## Repository layout

```text
hyprglass/
├── config/
│   ├── btop/
│   ├── cava/
│   ├── fastfetch/
│   ├── gtk-3.0/
│   ├── gtk-4.0/
│   ├── hypr/
│   │   └── conf.d/
│   ├── kitty/
│   ├── mako/
│   ├── rofi/
│   ├── theme/
│   │   ├── generated/
│   │   └── matugen/
│   │       └── templates/
│   └── waybar/
├── local/
│   └── bin/
├── wallpapers/
├── AUDIT.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── install.sh
├── LICENSE
└── README.md
```

The repository intentionally uses `config/` and `local/bin/` instead of hidden source directories so it stays readable on GitHub. The installer maps them to `~/.config/` and `~/.local/bin/` on the target machine.

## Architecture

### 1. hyprpaper owns wallpaper state
`hyprpaper` is the actual wallpaper setter. `matugen` does **not** own wallpaper setting.

`theme-apply` normalizes any selected wallpaper into a managed path under:

```text
~/Pictures/Wallpapers/hyprglass/current.<ext>
```

and rewrites `~/.config/hypr/hyprpaper.conf` to point to that managed file.

That makes wallpaper state coherent across reboots, randomization, and runtime reloads.

### 2. Theme state is centralized
The runtime theme pipeline is:

```text
wallpaper
  -> ~/.local/bin/theme-apply
  -> matugen templates
  -> ~/.config/theme/generated/*
  -> Hyprland / Waybar / Rofi / Kitty / Mako / GTK accents
```

Accent color is not scattered across component configs.

### 3. Hyprland is modular by design
`config/hypr/hyprland.conf` stays thin and sources dedicated fragments for:

- monitors
- environment
- GPU selection
- input and gestures
- general layout
- decoration and blur
- animations
- rules
- keybinds
- autostart

### 4. NVIDIA is explicit, not accidental
When an NVIDIA GPU is detected, the installer deliberately chooses the proprietary DKMS path and writes a dedicated GPU fragment for Hyprland. On hybrid laptops, NVIDIA is intentionally prioritized when you asked for real NVIDIA rendering.

That is a tradeoff: it increases the chance that Hyprland actually renders on NVIDIA, but it also increases idle power draw and heat.

## Installation

### Standard install

```bash
git clone https://github.com/Andre-cmd-rgb/hyprglass.git
cd hyprglass
chmod +x install.sh
./install.sh
```

### One-line install

```bash
git clone https://github.com/Andre-cmd-rgb/hyprglass.git && cd hyprglass && chmod +x install.sh && ./install.sh
```

## What the installer does

- verifies Arch Linux + `pacman`
- validates the repository before touching live config
- backs up only hyprglass-managed files and system files it owns
- installs official packages
- auto-detects NVIDIA and installs the proprietary DKMS path when needed
- removes `nvidia-open` / `nvidia-open-dkms` first if they are present, so the kernel-module path stays consistent
- detects common installed kernels and installs matching headers for `nvidia-dkms`
- deploys only hyprglass-managed config directories and helper scripts
- writes portal preferences explicitly
- writes machine-specific GPU config into `~/.config/hypr/conf.d/11-gpu.conf`
- enables required system services
- enables audio user units
- detects your current keyboard layout and lets you override it during install
- creates the `greeter` system user if it does not already exist and configures greetd so Hyprland auto-starts on boot without typing `Hyprland` manually
- configures a dedicated graphical gtkgreet session so logout returns to a real login screen instead of a TTY
- runs initial theme generation when a wallpaper is available

## Installer safety model

The installer is deliberately scoped.

It **does not** run `rsync --delete` against your whole `~/.config`. It synchronizes only the directories owned by hyprglass, which avoids the classic dotfiles-repo disaster of deleting unrelated user configuration.

It also backs up the system files that hyprglass itself manages for NVIDIA support:

- `/etc/modprobe.d/hyprglass-nvidia.conf`
- `/etc/udev/rules.d/61-hyprglass-drm-devices.rules`
- `/etc/mkinitcpio.conf`
- `/etc/greetd/config.toml`

## Wallpapers

The active wallpaper is also mirrored into `/var/lib/hyprglass/wallpapers/current`, which is what the graphical greeter uses. That keeps the greeter background aligned with the desktop wallpaper instead of showing a disconnected stock image.

Preferred repo default:

```text
wallpapers/default.png
```

If present, the installer copies it to:

```text
~/Pictures/Wallpapers/hyprglass/default.png
```

The runtime script then normalizes the active wallpaper to:

```text
~/Pictures/Wallpapers/hyprglass/current.<ext>
```

and updates a `current` symlink beside it.

## Keybindings

| Key | Action |
|---|---|
| `Super + Return` | Open Kitty |
| `Super + Shift + E` | Open Kitty and attach/create `tmux` session |
| `Super + Space` | Open Spotlight-style Rofi launcher |
| `Super + E` | Open Thunar |
| `Super + N` | Open terminal Wi-Fi control (`impala`) |
| `Super + A` | Open terminal audio control (`pulsemixer`/`alsamixer`) |
| `Super + B` | Open Blueman manager |
| `Super + Shift + D` | Toggle notification DND |
| `Super + Shift + W` | Random wallpaper + regenerate theme |
| `Super + Shift + Q` | Close focused window |
| `Super + Shift + C` | Exit Hyprland |
| `Super + F` | Fullscreen |
| `Super + Shift + F` | Toggle floating |
| `Super + Shift + R` | Reload Hyprland config |
| `Super + H/J/K/L` | Focus movement |
| `Super + Shift + H/J/K/L` | Move window |
| `Super + 1..0` | Switch workspace |
| `Super + Shift + 1..0` | Move window to workspace |

## Graphical login flow

The repo uses **greetd + gtkgreet** with two distinct behaviors:

- **boot:** `initial_session` starts Hyprland automatically for your user
- **after logout:** `default_session` starts a dedicated Hyprland greeter session running `gtkgreet`

That gives you fast automatic startup on boot, but still returns to a proper graphical login screen after logout.

The greeter is styled to match hyprglass: the same wallpaper, rounded translucent login card, dark GTK base, and Hyprland blur/shadow behind the card.

## Dynamic theming

Apply a specific wallpaper:

```bash
~/.local/bin/theme-apply /absolute/path/to/wallpaper.png
```

Pick a random wallpaper from your wallpaper directory:

```bash
~/.local/bin/theme-random
```

`theme-apply` does the following:
- accepts an explicit wallpaper path or resolves a fallback
- normalizes that wallpaper into the managed hyprglass wallpaper location
- rewrites `hyprpaper.conf`
- runs `matugen` non-interactively with deterministic source color selection
- reloads hyprpaper through Hyprland IPC when available
- reloads Hyprland config
- refreshes Waybar
- reloads Mako
- updates Kitty colors when possible

## Scaling

Default monitor scale is **1.67**.

That is deliberate for this build: it fits more on a 4K 16-inch laptop panel than 2x while still staying usable day to day. It is a fractional scale, so some Xwayland apps can still look less clean than they do at an integer scale.

Edit this file if you want to change it later:

```text
~/.config/hypr/conf.d/00-monitors.conf
```

## Recovery / rollback

If the installer touched an existing hyprglass setup, the backup is stored at:

```text
~/.config-backups/hyprglass/<timestamp>/
```

That backup contains:
- managed user config owned by hyprglass
- managed helper scripts in `~/.local/bin`
- portal config written by hyprglass
- managed NVIDIA-related system files when present

## Linux limitations

hyprglass can make the shell coherent. It cannot make Linux behave like macOS everywhere.

### GTK traffic-light buttons
GTK/libadwaita apps can override headerbar decoration behavior. The repo sets sane defaults and best-effort CSS, but universal macOS-style traffic lights are not enforceable across all Linux apps.

### Blur consistency
Hyprland can blur layer-shell clients and transparent surfaces, but exact visual behavior still depends on how each client renders and what namespace/layer it exposes.

### NVIDIA tradeoff
If you explicitly want Hyprland to render on NVIDIA on a hybrid laptop, the repo can push the system in that direction. That costs battery life, idle power, and usually some thermals.

## Project status

`hyprglass` is intended to be production-ready for fresh Arch installs, but it is still a Linux desktop environment project, not a sealed appliance. Read `AUDIT.md` for the hard technical audit and the rationale behind the current design.

## Login flow

`hyprglass` configures `greetd` plus `gtkgreet` so you do not have to sign in on a TTY and type `Hyprland` manually. On boot, `greetd` starts an initial Hyprland session automatically once per boot. If you log out, it returns to a dedicated graphical greeter session under Hyprland, using the same wallpaper and a rounded translucent login card.

## Keyboard layout

During install, `install.sh` tries to detect your current layout from `localectl` or `/etc/vconsole.conf`, then lets you confirm or override it. The final machine-specific value is written to:

```text
~/.config/hypr/conf.d/21-local-input.conf
```


## Terminal controls

- Audio opens in `pulsemixer` inside Kitty.
- Wi-Fi / network opens in `impala` inside Kitty.
- Waybar click actions and `SUPER+A` / `SUPER+N` launch them as floating terminal tools.


## Terminal control tools

Hyprglass uses terminal-first control surfaces for radios and audio. Bluetooth opens in `bluetui`. Wi-Fi/network opens in `impala` only when `iwd` is the active wireless stack and NetworkManager is not running; otherwise it falls back to `impala`, because `impala` is designed around `iwd` and should not be forced into a NetworkManager-managed setup.


## Wi-Fi terminal UI note

Hyprglass launches **Impala** from Waybar and `Super+N`. Impala requires **iwd** to manage Wi-Fi. If you keep **NetworkManager** in charge of Wi-Fi, Impala will open but cannot manage networks until you move Wi-Fi management to `iwd`. Ethernet/LTE through NetworkManager can still remain in place.
