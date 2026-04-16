#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.config-backups/hyprland-shell"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

PACMAN_PKGS=(
  hyprland hyprpaper hyprpolkitagent
  xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  waybar rofi mako kitty thunar thunar-archive-plugin file-roller
  nwg-dock-hyprland matugen
  tmux btop fastfetch cava
  networkmanager network-manager-applet modemmanager
  pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber
  bluez bluez-utils blueman
  brightnessctl pavucontrol
  qt5-wayland qt6-wayland
  papirus-icon-theme ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
  rsync git base-devel
)

AUR_PKGS=()

color() { printf '[%sm%s[0m
' "$1" "$2"; }
info()  { color "1;36" "[INFO] $*"; }
ok()    { color "1;32" "[ OK ] $*"; }
warn()  { color "1;33" "[WARN] $*"; }
fail()  { color "1;31" "[FAIL] $*"; }

require_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    fail "Run this installer as your normal user, not root."
    exit 1
  fi
}

require_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    fail "sudo is required."
    exit 1
  fi
  sudo -v
}

install_yay_if_missing() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay already installed"
    return
  fi

  info "Installing yay"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (
    cd "$tmpdir/yay"
    makepkg -si --noconfirm
  )
  ok "yay installed"
}

install_packages() {
  info "Installing official packages"
  sudo pacman -Syu --noconfirm --needed "${PACMAN_PKGS[@]}"

  install_yay_if_missing

  if (( ${#AUR_PKGS[@]} > 0 )); then
    info "Installing AUR packages"
    yay -S --noconfirm --needed "${AUR_PKGS[@]}"
  else
    ok "No AUR packages required for this build"
  fi
}

backup_existing() {
  mkdir -p "$BACKUP_DIR"

  local paths=(
    "$HOME/.config/hypr"
    "$HOME/.config/waybar"
    "$HOME/.config/mako"
    "$HOME/.config/rofi"
    "$HOME/.config/kitty"
    "$HOME/.config/gtk-3.0"
    "$HOME/.config/gtk-4.0"
    "$HOME/.config/fastfetch"
    "$HOME/.config/btop"
    "$HOME/.config/cava"
    "$HOME/.config/theme"
    "$HOME/.config/xdg-desktop-portal"
    "$HOME/.local/bin/launch-rofi"
    "$HOME/.local/bin/launch-dock"
    "$HOME/.local/bin/toggle-dock"
    "$HOME/.local/bin/toggle-dnd"
    "$HOME/.local/bin/mako-status"
    "$HOME/.local/bin/theme-apply"
    "$HOME/.local/bin/theme-random"
  )

  info "Backing up existing configuration"
  for path in "${paths[@]}"; do
    if [[ -e "$path" ]]; then
      mkdir -p "$BACKUP_DIR$(dirname "${path#$HOME}")"
      cp -a "$path" "$BACKUP_DIR${path#$HOME}"
    fi
  done
  ok "Backup stored at $BACKUP_DIR"
}

deploy_files() {
  info "Deploying dotfiles"

  mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/Pictures/Wallpapers/hyprland-shell"

  rsync -a --delete "$REPO_DIR/.config/" "$HOME/.config/"
  rsync -a "$REPO_DIR/.local/bin/" "$HOME/.local/bin/"
  rsync -a "$REPO_DIR/wallpapers/" "$HOME/Pictures/Wallpapers/hyprland-shell/"

  chmod +x "$HOME/.local/bin/"*
  ok "Dotfiles deployed"
}

configure_portals() {
  info "Writing portal preferences"
  mkdir -p "$HOME/.config/xdg-desktop-portal"
  cat > "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf" <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.OpenURI=gtk
org.freedesktop.impl.portal.Print=gtk
EOF
  cp "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"      "$HOME/.config/xdg-desktop-portal/portals.conf"
  ok "Portal configuration written"
}

enable_services() {
  info "Enabling system services"
  sudo systemctl enable --now NetworkManager.service
  sudo systemctl enable --now ModemManager.service
  sudo systemctl enable --now bluetooth.service

  info "Enabling user audio services"
  systemctl --user daemon-reload || true
  systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service || true

  ok "Services enabled"
}

apply_theme() {
  info "Generating initial theme files"
  "$HOME/.local/bin/theme-apply" "$HOME/Pictures/Wallpapers/hyprland-shell/default.png"
  ok "Initial theme generated"
}

print_next_steps() {
  cat <<EOF

============================================================
hyprland-shell installed
============================================================

Backup:
  $BACKUP_DIR

First login:
  - launch Hyprland
  - press Super+Space for the launcher
  - press Super+D to toggle the dock
  - press Super+Shift+W to randomize wallpaper/theme

To apply your own wallpaper:
  ~/.local/bin/theme-apply /absolute/path/to/wallpaper.png

Notes:
  - Default scale is 2x, exactly as configured in ~/.config/hypr/conf.d/00-monitors.conf.
  - GTK traffic-light buttons are best-effort styling, not a universal Linux guarantee.
  - The portal setup uses Hyprland for compositor-specific features and GTK for FileChooser/OpenURI/Print.
  - Bluetooth pairing and tray control are provided by Blueman.

EOF
}

main() {
  require_not_root
  require_sudo
  backup_existing
  install_packages
  deploy_files
  configure_portals
  enable_services
  apply_theme
  print_next_steps
}

main "$@"
