#!/usr/bin/env bash
set -euo pipefail

umask 022

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_ROOT="$HOME/.config-backups/hyprglass"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

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
  rsync git base-devel pciutils jq libnotify
)

AUR_PKGS=()

NVIDIA_SUPPORT="${NVIDIA_SUPPORT:-auto}"   # auto | off
NVIDIA_DRIVER_PACKAGE="${NVIDIA_DRIVER_PACKAGE:-}"
# valid values:
#   ""                -> do not auto-install a kernel driver package
#   nvidia
#   nvidia-open
#   nvidia-dkms
#   nvidia-open-dkms
#   nvidia-lts
#   nvidia-open-lts

color() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
info()  { color "1;36" "[INFO] $*"; }
ok()    { color "1;32" "[ OK ] $*"; }
warn()  { color "1;33" "[WARN] $*"; }
fail()  { color "1;31" "[FAIL] $*"; }

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_not_root() {
  if [[ "$EUID" -eq 0 ]]; then
    fail "Run this installer as your normal user, not root."
    exit 1
  fi
}

require_arch() {
  if ! command_exists pacman; then
    fail "This installer expects an Arch-based system with pacman."
    exit 1
  fi
}

require_sudo() {
  if ! command_exists sudo; then
    fail "sudo is required."
    exit 1
  fi
  sudo -v
}

install_yay_if_missing() {
  if command_exists yay; then
    ok "yay already installed"
    return
  fi

  info "Installing yay"
  local tmpdir=""
  tmpdir="$(mktemp -d)"

  if ! git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"; then
    rm -rf -- "$tmpdir"
    fail "Failed to clone yay from the AUR."
    exit 1
  fi

  if ! (
    cd "$tmpdir/yay"
    makepkg -si --noconfirm
  ); then
    rm -rf -- "$tmpdir"
    fail "Failed to build/install yay."
    exit 1
  fi

  rm -rf -- "$tmpdir"
  ok "yay installed"
}

has_nvidia_gpu() {
  command_exists lspci || return 1
  lspci -nn | grep -E 'VGA|3D' | grep -qi 'NVIDIA'
}

has_installed_nvidia_driver() {
  local pkg
  for pkg in \
    nvidia nvidia-open nvidia-dkms nvidia-open-dkms nvidia-lts nvidia-open-lts \
    nvidia-utils
  do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

validate_nvidia_driver_package() {
  case "$NVIDIA_DRIVER_PACKAGE" in
    ""|nvidia|nvidia-open|nvidia-dkms|nvidia-open-dkms|nvidia-lts|nvidia-open-lts)
      ;;
    *)
      fail "Invalid NVIDIA_DRIVER_PACKAGE: $NVIDIA_DRIVER_PACKAGE"
      exit 1
      ;;
  esac
}

append_kernel_headers_for_installed_kernels() {
  local -n _dest="$1"

  pacman -Q linux >/dev/null 2>&1 && _dest+=(linux-headers)
  pacman -Q linux-lts >/dev/null 2>&1 && _dest+=(linux-lts-headers)
  pacman -Q linux-zen >/dev/null 2>&1 && _dest+=(linux-zen-headers)
  pacman -Q linux-hardened >/dev/null 2>&1 && _dest+=(linux-hardened-headers)
}

install_nvidia_support_if_needed() {
  validate_nvidia_driver_package

  if [[ "$NVIDIA_SUPPORT" == "off" ]]; then
    info "NVIDIA support disabled by configuration"
    return
  fi

  if ! has_nvidia_gpu; then
    info "No NVIDIA GPU detected; skipping NVIDIA-specific setup"
    return
  fi

  info "NVIDIA GPU detected"

  local pkgs=(
    libva-nvidia-driver
    nvidia-settings
  )

  if has_installed_nvidia_driver; then
    ok "NVIDIA driver stack already present"
  else
    if [[ -z "$NVIDIA_DRIVER_PACKAGE" ]]; then
      warn "NVIDIA GPU found but no explicit NVIDIA kernel driver package is installed."
      warn "If you still need one, rerun with NVIDIA_DRIVER_PACKAGE set to:"
      warn "  nvidia | nvidia-open | nvidia-dkms | nvidia-open-dkms | nvidia-lts | nvidia-open-lts"
      warn "Continuing with userspace NVIDIA Wayland support only."
    else
      info "Installing NVIDIA driver package: $NVIDIA_DRIVER_PACKAGE"
      pkgs+=("$NVIDIA_DRIVER_PACKAGE")

      if [[ "$NVIDIA_DRIVER_PACKAGE" == *"-dkms" ]]; then
        pkgs+=(dkms)
        append_kernel_headers_for_installed_kernels pkgs
      fi
    fi
  fi

  sudo pacman -S --noconfirm --needed "${pkgs[@]}"
  ok "NVIDIA support packages installed"
}

install_packages() {
  info "Installing official packages"
  sudo pacman -Syu --noconfirm --needed "${PACMAN_PKGS[@]}"

  install_nvidia_support_if_needed

  if (( ${#AUR_PKGS[@]} > 0 )); then
    install_yay_if_missing
    info "Installing AUR packages"
    yay -S --noconfirm --needed "${AUR_PKGS[@]}"
  else
    ok "No AUR packages required for this build"
  fi
}

backup_existing() {
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
    "$HOME/.config/hypr/conf.d/15-nvidia.conf"
    "$HOME/.local/bin/launch-rofi"
    "$HOME/.local/bin/launch-dock"
    "$HOME/.local/bin/toggle-dock"
    "$HOME/.local/bin/toggle-dnd"
    "$HOME/.local/bin/mako-status"
    "$HOME/.local/bin/theme-apply"
    "$HOME/.local/bin/theme-random"
  )

  local path rel parent copied_any=0

  info "Backing up existing configuration"

  for path in "${paths[@]}"; do
    if [[ -e "$path" || -L "$path" ]]; then
      if (( copied_any == 0 )); then
        mkdir -p "$BACKUP_DIR"
        copied_any=1
      fi

      rel="${path#$HOME/}"
      parent="$(dirname "$rel")"

      mkdir -p "$BACKUP_DIR/$parent"
      cp -a "$path" "$BACKUP_DIR/$rel"
    fi
  done

  if (( copied_any == 1 )); then
    ok "Backup stored at $BACKUP_DIR"
  else
    ok "No existing managed configuration found to back up"
  fi
}

sync_children() {
  local src_root="$1"
  local dest_root="$2"
  local child dest

  shopt -s nullglob dotglob

  for child in "$src_root"/*; do
    [[ -e "$child" || -L "$child" ]] || continue

    dest="$dest_root/$(basename "$child")"

    if [[ -d "$child" && ! -L "$child" ]]; then
      mkdir -p "$dest"
      rsync -a --delete "$child/" "$dest/"
    else
      mkdir -p "$dest_root"
      rsync -a "$child" "$dest"
    fi
  done

  shopt -u nullglob dotglob
}

deploy_files() {
  info "Deploying repo files"

  mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/Pictures/Wallpapers/hyprglass"

  local config_src="$REPO_DIR/config"
  local local_bin_src="$REPO_DIR/local/bin"
  local script

  [[ -d "$REPO_DIR/.config" ]] && config_src="$REPO_DIR/.config"
  [[ -d "$REPO_DIR/.local/bin" ]] && local_bin_src="$REPO_DIR/.local/bin"

  if [[ ! -d "$config_src" || ! -d "$local_bin_src" ]]; then
    fail "Repo layout invalid. Expected config/ and local/bin/ or .config/ and .local/bin/."
    exit 1
  fi

  sync_children "$config_src" "$HOME/.config"
  sync_children "$local_bin_src" "$HOME/.local/bin"

  if [[ -d "$REPO_DIR/wallpapers" ]]; then
    sync_children "$REPO_DIR/wallpapers" "$HOME/Pictures/Wallpapers/hyprglass"
  fi

  shopt -s nullglob
  for script in "$local_bin_src"/*; do
    [[ -f "$script" ]] || continue
    chmod 0755 "$HOME/.local/bin/$(basename "$script")"
  done
  shopt -u nullglob

  ok "Repo files deployed"
}

write_hypr_nvidia_conf() {
  if [[ "$NVIDIA_SUPPORT" == "off" ]]; then
    return
  fi

  if ! has_nvidia_gpu; then
    return
  fi

  mkdir -p "$HOME/.config/hypr/conf.d"

  cat > "$HOME/.config/hypr/conf.d/15-nvidia.conf" <<'EOF'
# Generated by install.sh
# Hyprland + NVIDIA Wayland support

env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

env = QT_QPA_PLATFORM,wayland;xcb
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1

env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,nvidia
env = NVD_BACKEND,direct

env = ELECTRON_OZONE_PLATFORM_HINT,auto
EOF

  ok "Hyprland NVIDIA configuration written"
}

configure_portals() {
  info "Writing portal preferences"

  local portal_dir="$HOME/.config/xdg-desktop-portal"
  local portal_file="$portal_dir/hyprland-portals.conf"

  mkdir -p "$portal_dir"

  cat > "$portal_file" <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.OpenURI=gtk
org.freedesktop.impl.portal.Print=gtk
EOF

  install -m 0644 "$portal_file" "$portal_dir/portals.conf"
  ok "Portal configuration written"
}

enable_services() {
  info "Enabling system services"
  sudo systemctl enable --now NetworkManager.service
  sudo systemctl enable --now ModemManager.service
  sudo systemctl enable --now bluetooth.service
  ok "System services enabled"

  info "Enabling user audio services"
  if systemctl --user daemon-reload >/dev/null 2>&1; then
    if systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1; then
      ok "User audio services enabled"
    else
      warn "Could not enable user audio services in the current session."
      warn "After logging into Hyprland, run:"
      warn "  systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service"
    fi
  else
    warn "No active user systemd session detected."
    warn "After logging into Hyprland, run:"
    warn "  systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service"
  fi
}

apply_theme() {
  local wall_dir="$HOME/Pictures/Wallpapers/hyprglass"
  local theme_apply="$HOME/.local/bin/theme-apply"
  local default_wall="$wall_dir/default.png"
  local first_wall=""

  if [[ ! -x "$theme_apply" ]]; then
    warn "theme-apply is missing or not executable."
    warn "Skipping initial wallpaper/theme generation."
    return
  fi

  if [[ -f "$default_wall" ]]; then
    info "Generating initial theme files from default.png"
    if "$theme_apply" "$default_wall"; then
      ok "Initial theme generated"
    else
      warn "Theme generation failed; installation completed anyway."
    fi
    return
  fi

  first_wall="$(find "$wall_dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort | head -n 1)"

  if [[ -n "$first_wall" ]]; then
    info "Generating initial theme files from the first available wallpaper"
    if "$theme_apply" "$first_wall"; then
      ok "Initial theme generated"
    else
      warn "Theme generation failed; installation completed anyway."
    fi
    return
  fi

  warn "No wallpaper found yet. Add wallpapers/default.png to the repo or copy one to ~/Pictures/Wallpapers/hyprglass/ later."
  warn "Skipping initial wallpaper/theme generation. Fallback generated theme files remain in place."
}

print_next_steps() {
  cat <<EOF

============================================================
hyprglass installed
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

Recommended default wallpaper path:
  ~/Pictures/Wallpapers/hyprglass/default.png

Notes:
  - Default scale is 2x, exactly as configured in ~/.config/hypr/conf.d/00-monitors.conf.
  - GTK traffic-light buttons are best-effort styling, not a universal Linux guarantee.
  - The portal setup uses Hyprland for compositor-specific features and GTK for FileChooser/OpenURI/Print.
  - Bluetooth pairing and tray control are provided by Blueman.
  - If you use uwsm later, move NVIDIA env vars to ~/.config/uwsm/env.

EOF
}

main() {
  require_not_root
  require_arch
  require_sudo
  backup_existing
  install_packages
  deploy_files
  write_hypr_nvidia_conf
  configure_portals
  enable_services
  apply_theme
  print_next_steps
}

main "$@"
