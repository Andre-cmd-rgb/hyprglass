#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROJECT_NAME="hyprglass"
PROJECT_VERSION="1.3.0"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.config-backups/$PROJECT_NAME"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/$PROJECT_NAME"
PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
SYSTEM_CONFIG_BACKUP_DIR="$BACKUP_DIR/system"
BACKUP_CREATED=0
YAY_TMPDIR=""
CONFIG_SRC=""
LOCAL_BIN_SRC=""
NVIDIA_PRESENT=0
INTEL_GPU_PRESENT=0
NVIDIA_PCI_ADDR=""
INTEL_PCI_ADDR=""
NVIDIA_GPU_CONF="$HOME/.config/hypr/conf.d/11-gpu.conf"
SHARED_STATE_ROOT="/var/lib/hyprglass"
SHARED_WALLPAPER_DIR="$SHARED_STATE_ROOT/wallpapers"
SHARED_GREETER_DIR="$SHARED_STATE_ROOT/greeter"
GREETD_HOME="/var/lib/greetd"
KEYBOARD_LAYOUT="us"
KEYBOARD_VARIANT=""

PACMAN_PKGS=(
  hyprland hyprpaper hyprpolkitagent
  xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  waybar rofi mako kitty thunar thunar-archive-plugin file-roller
  nwg-dock-hyprland matugen
  greetd greetd-gtkgreet
  tmux btop fastfetch cava
  networkmanager network-manager-applet modemmanager
  pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber
  bluez bluez-utils blueman
  brightnessctl pavucontrol pulsemixer
  qt5-wayland qt6-wayland
  papirus-icon-theme ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
  rsync git base-devel
)

AUR_PKGS=()

CONFIG_DIRS=(
  hypr
  waybar
  mako
  rofi
  kitty
  gtk-3.0
  gtk-4.0
  fastfetch
  btop
  cava
  theme
)

BIN_FILES=(
  launch-rofi
  launch-dock
  toggle-dock
  toggle-dnd
  mako-status
  theme-apply
  theme-random
  launch-audio
  launch-network
)

SYSTEM_SERVICES=(
  NetworkManager.service
  ModemManager.service
  bluetooth.service
)

USER_UNITS=(
  pipewire.socket
  pipewire-pulse.socket
  wireplumber.service
)

MANAGED_SYSTEM_FILES=(
  /etc/modprobe.d/hyprglass-nvidia.conf
  /etc/udev/rules.d/61-hyprglass-drm-devices.rules
  /etc/greetd/config.toml
  /etc/greetd/environments
  /etc/greetd/hyprland-greeter.conf
  /var/lib/greetd/.config/hypr/hyprpaper.conf
  /var/lib/hyprglass
)

color() {
  local code="$1"
  shift
  printf '\033[%sm%s\033[0m\n' "$code" "$*"
}

info()  { color "1;36" "[INFO] $*"; }
ok()    { color "1;32" "[ OK ] $*"; }
warn()  { color "1;33" "[WARN] $*"; }
fail()  { color "1;31" "[FAIL] $*"; }

on_error() {
  local line="$1"
  fail "Installer aborted at line $line."
  if [[ "$BACKUP_CREATED" -eq 1 ]]; then
    warn "Your backup is available at: $BACKUP_DIR"
  fi
}

cleanup_yay_tmp() {
  if [[ -n "$YAY_TMPDIR" && -d "$YAY_TMPDIR" ]]; then
    rm -rf "$YAY_TMPDIR"
  fi
}

trap 'on_error $LINENO' ERR
trap cleanup_yay_tmp EXIT

require_not_root() {
  if [[ "$EUID" -eq 0 ]]; then
    fail "Run this installer as your normal user, not root."
    exit 1
  fi
}

require_arch() {
  if [[ ! -r /etc/os-release ]]; then
    fail "Cannot verify operating system. /etc/os-release is missing."
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "arch" ]]; then
    fail "This installer targets Arch Linux. Detected: ${PRETTY_NAME:-unknown}."
    exit 1
  fi

  command -v pacman >/dev/null 2>&1 || { fail "pacman is required."; exit 1; }
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_json_file() {
  local file="$1"

  if command_exists jq; then
    jq empty "$file" >/dev/null
    return
  fi

  if command_exists python3; then
    python3 - <<PYJSON >/dev/null
import json, pathlib
json.loads(pathlib.Path(r"$file").read_text())
PYJSON
    return
  fi

  warn "Skipping strict JSON validation for $file because neither jq nor python3 is available yet."
}

require_sudo() {
  command -v sudo >/dev/null 2>&1 || { fail "sudo is required."; exit 1; }
  sudo -v
}

resolve_repo_sources() {
  CONFIG_SRC="$REPO_DIR/config"
  LOCAL_BIN_SRC="$REPO_DIR/local/bin"

  if [[ -d "$REPO_DIR/.config" ]]; then
    CONFIG_SRC="$REPO_DIR/.config"
  fi
  if [[ -d "$REPO_DIR/.local/bin" ]]; then
    LOCAL_BIN_SRC="$REPO_DIR/.local/bin"
  fi

  if [[ ! -d "$CONFIG_SRC" || ! -d "$LOCAL_BIN_SRC" ]]; then
    fail "Repo layout is invalid. Expected config/ and local/bin/ (or .config/ and .local/bin/)."
    exit 1
  fi
}

validate_repo() {
  resolve_repo_sources

  info "Validating repository contents"

  local dir bin path line
  for dir in "${CONFIG_DIRS[@]}"; do
    [[ -d "$CONFIG_SRC/$dir" ]] || { fail "Missing required config directory: $CONFIG_SRC/$dir"; exit 1; }
  done

  for bin in "${BIN_FILES[@]}"; do
    [[ -f "$LOCAL_BIN_SRC/$bin" ]] || { fail "Missing helper script: $LOCAL_BIN_SRC/$bin"; exit 1; }
    bash -n "$LOCAL_BIN_SRC/$bin"
  done

  bash -n "$REPO_DIR/install.sh"
  validate_json_file "$CONFIG_SRC/waybar/config.jsonc"
  validate_json_file "$CONFIG_SRC/fastfetch/config.jsonc"

  while IFS= read -r line; do
    path="${line#source = }"
    path="${path/#~\/.config/$CONFIG_SRC}"
    [[ -f "$path" ]] || { fail "Hyprland source file is missing: $path"; exit 1; }
  done < <(grep -E '^source = ' "$CONFIG_SRC/hypr/hyprland.conf")

  if grep -R '{{ custom\.' "$CONFIG_SRC/theme/matugen/templates" >/dev/null 2>&1; then
    fail "Matugen templates still contain deprecated custom.* references."
    exit 1
  fi

  if grep -q '^\[config\.wallpaper\]' "$CONFIG_SRC/theme/matugen/config.toml"; then
    fail "matugen config still contains [config.wallpaper]; hyprpaper must own wallpaper setting."
    exit 1
  fi

  if grep -q '^\[config\.custom_keywords\]' "$CONFIG_SRC/theme/matugen/config.toml"; then
    fail "matugen config still contains deprecated [config.custom_keywords]."
    exit 1
  fi

  ok "Repository validation passed"
}

install_yay_if_missing() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay already installed"
    return
  fi

  info "Installing yay"
  YAY_TMPDIR="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$YAY_TMPDIR/yay"
  (
    cd "$YAY_TMPDIR/yay"
    makepkg -si --noconfirm
  )
  ok "yay installed"
}

detect_gpus() {
  local gpu_lines
  gpu_lines="$(lspci -Dnn | grep -E 'VGA compatible controller|3D controller|Display controller' || true)"

  if grep -qi 'NVIDIA' <<<"$gpu_lines"; then
    NVIDIA_PRESENT=1
    NVIDIA_PCI_ADDR="$(awk '/NVIDIA/ {print $1; exit}' <<<"$gpu_lines")"
  fi

  if grep -qi 'Intel' <<<"$gpu_lines"; then
    INTEL_GPU_PRESENT=1
    INTEL_PCI_ADDR="$(awk '/Intel/ {print $1; exit}' <<<"$gpu_lines")"
  fi
}

collect_nvidia_packages() {
  local pkgs=(nvidia-dkms nvidia-utils egl-wayland)
  local kernel headers
  mapfile -t kernels < <(pacman -Qq | grep -Ex 'linux|linux-lts|linux-zen|linux-hardened' || true)

  if (( ${#kernels[@]} == 0 )); then
    warn "Could not detect an installed kernel package cleanly. Assuming linux/linux-headers."
    kernels=(linux)
  fi

  for kernel in "${kernels[@]}"; do
    case "$kernel" in
      linux) headers="linux-headers" ;;
      linux-lts) headers="linux-lts-headers" ;;
      linux-zen) headers="linux-zen-headers" ;;
      linux-hardened) headers="linux-hardened-headers" ;;
      *)
        warn "Unknown kernel package '$kernel'. Install matching headers manually before using nvidia-dkms."
        continue
        ;;
    esac
    pkgs+=("$headers")
  done

  if pacman -Si lib32-nvidia-utils >/dev/null 2>&1; then
    pkgs+=(lib32-nvidia-utils)
  fi

  printf '%s\n' "${pkgs[@]}" | awk '!seen[$0]++'
}

install_packages() {
  info "Synchronizing package databases and installing official packages"
  sudo pacman -Syu --noconfirm --needed "${PACMAN_PKGS[@]}"

  if (( NVIDIA_PRESENT == 1 )); then
    info "NVIDIA GPU detected. Installing proprietary DKMS driver path."
    mapfile -t nvidia_pkgs < <(collect_nvidia_packages)
    sudo pacman -S --noconfirm --needed "${nvidia_pkgs[@]}"
  else
    ok "No NVIDIA GPU detected; skipping NVIDIA driver stack"
  fi

  if (( ${#AUR_PKGS[@]} > 0 )); then
    install_yay_if_missing
    info "Installing AUR packages"
    yay -S --noconfirm --needed "${AUR_PKGS[@]}"
  else
    ok "No AUR packages required for this release; skipping yay bootstrap"
  fi
}

normalize_vc_keymap_to_xkb() {
  local keymap="$1"
  case "$keymap" in
    es*|la-latin1|latam*) printf 'es\n' ;;
    it*) printf 'it\n' ;;
    us*) printf 'us\n' ;;
    de*) printf 'de\n' ;;
    fr*) printf 'fr\n' ;;
    pt*) printf 'pt\n' ;;
    br*|abnt*) printf 'br\n' ;;
    *) printf 'us\n' ;;
  esac
}

detect_keyboard_defaults() {
  local x11_layout="" x11_variant="" vc_keymap=""

  if command_exists localectl; then
    x11_layout="$(localectl status 2>/dev/null | sed -n 's/^[[:space:]]*X11 Layout:[[:space:]]*//p' | head -n 1)"
    x11_variant="$(localectl status 2>/dev/null | sed -n 's/^[[:space:]]*X11 Variant:[[:space:]]*//p' | head -n 1)"
    vc_keymap="$(localectl status 2>/dev/null | sed -n 's/^[[:space:]]*VC Keymap:[[:space:]]*//p' | head -n 1)"
  fi

  if [[ -z "$vc_keymap" && -r /etc/vconsole.conf ]]; then
    vc_keymap="$(sed -n 's/^KEYMAP=//p' /etc/vconsole.conf | head -n 1 | tr -d '"')"
  fi

  if [[ -n "$x11_layout" ]]; then
    KEYBOARD_LAYOUT="${x11_layout%%,*}"
  elif [[ -n "$vc_keymap" ]]; then
    KEYBOARD_LAYOUT="$(normalize_vc_keymap_to_xkb "$vc_keymap")"
  else
    KEYBOARD_LAYOUT="us"
  fi

  KEYBOARD_VARIANT="$x11_variant"
}

prompt_keyboard_config() {
  local input=""
  detect_keyboard_defaults

  info "Detected keyboard layout: $KEYBOARD_LAYOUT${KEYBOARD_VARIANT:+ ($KEYBOARD_VARIANT)}"

  if [[ -t 0 ]]; then
    printf 'Keyboard layout for Hyprland [%s]: ' "$KEYBOARD_LAYOUT"
    read -r input || true
    if [[ -n "$input" ]]; then
      KEYBOARD_LAYOUT="$input"
    fi

    printf 'Keyboard variant for Hyprland [%s]: ' "${KEYBOARD_VARIANT:-none}"
    read -r input || true
    if [[ -n "$input" ]]; then
      KEYBOARD_VARIANT="$input"
    fi
  fi

  [[ -n "$KEYBOARD_LAYOUT" ]] || KEYBOARD_LAYOUT="us"
}

backup_existing() {
  local existing=0 target dir bin file

  for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -e "$HOME/.config/$dir" ]]; then
      existing=1
      break
    fi
  done

  if [[ "$existing" -eq 0 ]]; then
    for bin in "${BIN_FILES[@]}"; do
      if [[ -e "$HOME/.local/bin/$bin" ]]; then
        existing=1
        break
      fi
    done
  fi

  [[ -e "$PORTAL_DIR" ]] && existing=1

  for file in "${MANAGED_SYSTEM_FILES[@]}" /etc/mkinitcpio.conf; do
    if [[ -e "$file" ]]; then
      existing=1
      break
    fi
  done

  if [[ "$existing" -eq 0 ]]; then
    ok "No existing managed hyprglass files found; skipping backup"
    return
  fi

  mkdir -p "$BACKUP_DIR"
  BACKUP_CREATED=1
  info "Backing up managed configuration"

  for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -e "$HOME/.config/$dir" ]]; then
      target="$BACKUP_DIR/.config/$dir"
      mkdir -p "$(dirname "$target")"
      cp -a "$HOME/.config/$dir" "$target"
    fi
  done

  for bin in "${BIN_FILES[@]}"; do
    if [[ -e "$HOME/.local/bin/$bin" ]]; then
      target="$BACKUP_DIR/.local/bin/$bin"
      mkdir -p "$(dirname "$target")"
      cp -a "$HOME/.local/bin/$bin" "$target"
    fi
  done

  if [[ -e "$PORTAL_DIR" ]]; then
    target="$BACKUP_DIR/.config/xdg-desktop-portal"
    mkdir -p "$(dirname "$target")"
    cp -a "$PORTAL_DIR" "$target"
  fi

  mkdir -p "$SYSTEM_CONFIG_BACKUP_DIR"
  for file in "${MANAGED_SYSTEM_FILES[@]}" /etc/mkinitcpio.conf; do
    if [[ -e "$file" ]]; then
      sudo cp -a "$file" "$SYSTEM_CONFIG_BACKUP_DIR/$(basename "$file")"
    fi
  done

  ok "Backup stored at $BACKUP_DIR"
}

sync_config_dirs() {
  local dir
  for dir in "${CONFIG_DIRS[@]}"; do
    install -d "$HOME/.config/$dir"
    rsync -a --delete "$CONFIG_SRC/$dir/" "$HOME/.config/$dir/"
  done
}

sync_bin_files() {
  local bin
  install -d "$HOME/.local/bin"
  for bin in "${BIN_FILES[@]}"; do
    install -m 755 "$LOCAL_BIN_SRC/$bin" "$HOME/.local/bin/$bin"
  done
}

sync_wallpapers() {
  install -d "$WALLPAPER_DIR"
  if [[ -d "$REPO_DIR/wallpapers" ]]; then
    find "$REPO_DIR/wallpapers" -maxdepth 1 -type f \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.jxl' \) \
      -exec cp -a {} "$WALLPAPER_DIR/" \;
  fi
}

write_local_input_conf() {
  local target="$HOME/.config/hypr/conf.d/21-local-input.conf"
  install -d "$(dirname "$target")"

  {
    echo '# Generated by hyprglass install.sh'
    echo 'input {'
    printf '    kb_layout = %s\n' "$KEYBOARD_LAYOUT"
    if [[ -n "$KEYBOARD_VARIANT" ]]; then
      printf '    kb_variant = %s\n' "$KEYBOARD_VARIANT"
    fi
    echo '}'
  } > "$target"
}

deploy_files() {
  info "Deploying project files"
  sync_config_dirs
  sync_bin_files
  sync_wallpapers
  write_local_input_conf
  ok "Project files deployed"
}

configure_portals() {
  info "Writing portal preferences"
  install -d "$PORTAL_DIR"

  cat > "$PORTAL_DIR/hyprland-portals.conf" <<'PORTALS'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.OpenURI=gtk
org.freedesktop.impl.portal.Print=gtk
PORTALS

  cp "$PORTAL_DIR/hyprland-portals.conf" "$PORTAL_DIR/portals.conf"
  ok "Portal configuration written"
}

write_gpu_conf() {
  install -d "$(dirname "$NVIDIA_GPU_CONF")"

  if (( NVIDIA_PRESENT == 0 )); then
    cat > "$NVIDIA_GPU_CONF" <<'GPUCONF'
# No NVIDIA GPU detected during install.
# hyprglass leaves multi-GPU device selection to Hyprland defaults on this machine.
GPUCONF
    return
  fi

  local devices=(/dev/dri/hyprglass-nvidia)
  if (( INTEL_GPU_PRESENT == 1 )); then
    devices+=(/dev/dri/hyprglass-secondary)
  fi

  {
    echo '# Generated by hyprglass install.sh'
    echo '# NVIDIA is prioritized deliberately on this machine.'
    printf 'env = AQ_DRM_DEVICES,%s\n' "$(IFS=:; echo "${devices[*]}")"
    echo 'env = GBM_BACKEND,nvidia-drm'
    echo 'env = __GLX_VENDOR_LIBRARY_NAME,nvidia'
  } > "$NVIDIA_GPU_CONF"
}

write_nvidia_modprobe_conf() {
  (( NVIDIA_PRESENT == 1 )) || return 0
  sudo install -d /etc/modprobe.d
  sudo tee /etc/modprobe.d/hyprglass-nvidia.conf >/dev/null <<'MODPROBE'
options nvidia_drm modeset=1
MODPROBE
}

write_udev_rules() {
  (( NVIDIA_PRESENT == 1 )) || return 0

  sudo install -d /etc/udev/rules.d
  {
    echo '# Generated by hyprglass install.sh'
    if [[ -n "$NVIDIA_PCI_ADDR" ]]; then
      printf 'SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="%s", SYMLINK+="dri/hyprglass-nvidia"\n' "$NVIDIA_PCI_ADDR"
    fi
    if (( INTEL_GPU_PRESENT == 1 )) && [[ -n "$INTEL_PCI_ADDR" ]]; then
      printf 'SUBSYSTEM=="drm", KERNEL=="card*", KERNELS=="%s", SYMLINK+="dri/hyprglass-secondary"\n' "$INTEL_PCI_ADDR"
    fi
  } | sudo tee /etc/udev/rules.d/61-hyprglass-drm-devices.rules >/dev/null

  sudo udevadm control --reload-rules >/dev/null 2>&1 || true
  sudo udevadm trigger -c add /dev/dri >/dev/null 2>&1 || true
}

configure_mkinitcpio_modules() {
  (( NVIDIA_PRESENT == 1 )) || return 0
  local mkinitcpio_conf="/etc/mkinitcpio.conf"
  local current_line current_inner item
  local -a modules wanted

  [[ -f "$mkinitcpio_conf" ]] || { warn "mkinitcpio.conf not found; skipping initramfs module optimization"; return 0; }

  current_line="$(grep -E '^MODULES=\(' "$mkinitcpio_conf" || true)"
  current_inner="${current_line#MODULES=(}"
  current_inner="${current_inner%)}"
  local IFS=' '
  read -r -a modules <<<"$current_inner"

  wanted=()
  if (( INTEL_GPU_PRESENT == 1 )); then
    wanted+=(i915)
  fi
  wanted+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

  for item in "${modules[@]}"; do
    [[ -n "$item" ]] || continue
    case " ${wanted[*]} " in
      *" $item "*) ;;
      *) wanted+=("$item") ;;
    esac
  done

  local new_line="MODULES=(${wanted[*]})"
  if [[ "$current_line" != "$new_line" ]]; then
    if [[ -n "$current_line" ]]; then
      sudo sed -i "s|^MODULES=(.*)|$new_line|" "$mkinitcpio_conf"
    else
      printf '%s\n' "$new_line" | sudo tee -a "$mkinitcpio_conf" >/dev/null
    fi
    info "Rebuilding initramfs because NVIDIA DKMS/KMS module order changed"
    sudo mkinitcpio -P
  fi
}

configure_nvidia() {
  write_gpu_conf
  (( NVIDIA_PRESENT == 1 )) || return 0
  info "Configuring NVIDIA rendering path for Hyprland"
  write_nvidia_modprobe_conf
  write_udev_rules
  configure_mkinitcpio_modules
  ok "NVIDIA configuration written"
}

prepare_shared_greeter_assets() {
  info "Preparing shared greeter assets"

  sudo install -d -m 755 "$SHARED_STATE_ROOT"
  sudo install -d -m 755 "$SHARED_WALLPAPER_DIR" "$SHARED_GREETER_DIR"
  sudo chown "$USER":"$USER" "$SHARED_WALLPAPER_DIR" "$SHARED_GREETER_DIR"

  if [[ -f "$HOME/.config/theme/generated/gtkgreet.css" ]]; then
    install -m 644 "$HOME/.config/theme/generated/gtkgreet.css" "$SHARED_GREETER_DIR/gtkgreet.css"
  fi

  if [[ -f "$WALLPAPER_DIR/default.png" ]]; then
    install -m 644 "$WALLPAPER_DIR/default.png" "$SHARED_WALLPAPER_DIR/default.png"
    if [[ ! -e "$SHARED_WALLPAPER_DIR/current" ]]; then
      ln -sfn default.png "$SHARED_WALLPAPER_DIR/current"
    fi
  fi

  sudo install -d -m 755 "$GREETD_HOME/.config/hypr"
  sudo tee "$GREETD_HOME/.config/hypr/hyprpaper.conf" >/dev/null <<EOF_HYPRPAPER
ipc = true
splash = false

wallpaper {
    monitor =
    path = $SHARED_WALLPAPER_DIR/current
    fit_mode = cover
}
EOF_HYPRPAPER
  sudo chown -R greetd:greetd "$GREETD_HOME/.config"

  ok "Shared greeter assets prepared"
}

configure_greetd() {
  info "Configuring greetd with automatic Hyprland start on boot and a graphical greeter after logout"
  sudo install -d /etc/greetd

  sudo tee /etc/greetd/environments >/dev/null <<'EOF_ENV'
Hyprland
EOF_ENV

  sudo tee /etc/greetd/hyprland-greeter.conf >/dev/null <<'EOF_GREETER_HYPR'
monitor = , preferred, auto, 1.75

xwayland {
    force_zero_scaling = true
}

env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = GDK_BACKEND,wayland,x11,*
env = GTK_THEME,Adwaita:dark
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24

general {
    gaps_in = 0
    gaps_out = 0
    border_size = 0
    col.active_border = rgba(00000000)
    col.inactive_border = rgba(00000000)
    layout = dwindle
}

decoration {
    rounding = 22
    active_opacity = 1.0
    inactive_opacity = 1.0

    blur {
        enabled = true
        size = 8
        passes = 3
        noise = 0.02
        contrast = 1.0
        brightness = 1.0
        vibrancy = 0.18
        vibrancy_darkness = 0.2
        ignore_opacity = true
        new_optimizations = true
    }

    shadow {
        enabled = true
        range = 20
        render_power = 3
        color = rgba(00000066)
    }
}

animations {
    enabled = true
    bezier = standard, 0.20, 0.90, 0.10, 1.00
    bezier = overshot, 0.13, 0.99, 0.29, 1.10
    animation = windows, 1, 6, standard, slide
    animation = windowsIn, 1, 6, overshot, slide
    animation = windowsOut, 1, 5, standard, slide
    animation = fade, 1, 6, standard
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    key_press_enables_dpms = true
    mouse_move_enables_dpms = true
}

windowrule = match:class ^([Gg]tkgreet)$, float on, center on, size 760 640
windowrule = match:class ^([Gg]tkgreet)$, border_size 0, rounding 24

bind = CTRL ALT, BACKSPACE, exit
bind = CTRL ALT, DELETE, exit

exec-once = /usr/bin/hyprpaper
exec-once = /usr/bin/sh -lc '/usr/bin/gtkgreet -c /usr/bin/Hyprland -s /var/lib/hyprglass/greeter/gtkgreet.css; /usr/bin/hyprctl dispatch exit'
EOF_GREETER_HYPR

  local tmpfile
  tmpfile="$(mktemp)"
  cat > "$tmpfile" <<EOF_GREETD
[terminal]
vt = 1

[general]
source_profile = true
runfile = "/run/greetd/hyprglass.run"

[default_session]
command = "/usr/bin/Hyprland --config /etc/greetd/hyprland-greeter.conf"
user = "greeter"

[initial_session]
command = "/usr/bin/Hyprland"
user = "$USER"
EOF_GREETD

  sudo install -m 644 "$tmpfile" /etc/greetd/config.toml
  rm -f "$tmpfile"

  sudo systemctl set-default graphical.target >/dev/null 2>&1 || true
  ok "greetd configured"
}

enable_system_services() {
  local unit
  info "Enabling system services"
  for unit in "${SYSTEM_SERVICES[@]}"; do
    sudo systemctl enable --now "$unit"
  done
  sudo systemctl enable --now greetd.service >/dev/null 2>&1
  ok "System services enabled"
}

enable_user_units() {
  local unit

  if systemctl --user list-unit-files >/dev/null 2>&1; then
    info "Enabling user services in the active user session"
    for unit in "${USER_UNITS[@]}"; do
      systemctl --user enable "$unit" >/dev/null 2>&1 || true
      systemctl --user start "$unit" >/dev/null 2>&1 || true
    done
    ok "User services enabled for this account"
    return
  fi

  warn "No live systemd user session detected. Falling back to global enable for next login."
  sudo systemctl --global enable "${USER_UNITS[@]}" >/dev/null 2>&1 || true
}

apply_initial_theme() {
  local default_wall="$WALLPAPER_DIR/default.png"
  local first_wall=""

  if [[ -f "$default_wall" ]]; then
    info "Generating initial theme from default.png"
    if "$HOME/.local/bin/theme-apply" "$default_wall"; then
      ok "Initial theme generated"
    else
      warn "Initial theme generation failed. Install completed; fallback generated theme files remain active."
    fi
    return
  fi

  first_wall="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.jxl' \) | sort | head -n 1 || true)"
  if [[ -n "$first_wall" ]]; then
    info "Generating initial theme from the first available wallpaper"
    if "$HOME/.local/bin/theme-apply" "$first_wall"; then
      ok "Initial theme generated"
    else
      warn "Initial theme generation failed. Install completed; fallback generated theme files remain active."
    fi
    return
  fi

  warn "No wallpaper found yet. Add wallpapers/default.png to the repo or copy one to $WALLPAPER_DIR/."
  warn "Skipping initial wallpaper generation. Tracked fallback theme files remain active."
}

post_install_validation() {
  info "Running post-install validation"

  local dir bin
  for dir in "${CONFIG_DIRS[@]}"; do
    [[ -d "$HOME/.config/$dir" ]] || { fail "Missing deployed directory: $HOME/.config/$dir"; exit 1; }
  done

  for bin in "${BIN_FILES[@]}"; do
    [[ -x "$HOME/.local/bin/$bin" ]] || { fail "Missing deployed executable: $HOME/.local/bin/$bin"; exit 1; }
  done

  [[ -f "$HOME/.config/hypr/hyprland.conf" ]] || { fail "Hyprland config was not deployed"; exit 1; }
  [[ -f "$HOME/.config/hypr/conf.d/21-local-input.conf" ]] || { fail "Keyboard override fragment was not written"; exit 1; }
  [[ -f "$HOME/.config/theme/generated/colors.css" ]] || { fail "Fallback theme files are missing after deployment"; exit 1; }
  [[ -f "$PORTAL_DIR/hyprland-portals.conf" ]] || { fail "Portal configuration was not written"; exit 1; }
  [[ -f "$HOME/.config/hypr/conf.d/11-gpu.conf" ]] || { fail "GPU config fragment was not written"; exit 1; }
  sudo test -f /etc/greetd/config.toml || { fail "greetd configuration was not written"; exit 1; }
  sudo test -f /etc/greetd/hyprland-greeter.conf || { fail "Greeter Hyprland config was not written"; exit 1; }
  sudo test -f "$GREETD_HOME/.config/hypr/hyprpaper.conf" || { fail "Greeter hyprpaper config was not written"; exit 1; }

  ok "Post-install validation passed"
}

print_next_steps() {
  local backup_label="not needed"
  if [[ "$BACKUP_CREATED" -eq 1 ]]; then
    backup_label="$BACKUP_DIR"
  fi

  cat <<EOF

============================================================
$PROJECT_NAME $PROJECT_VERSION installed
============================================================

Backup:
  $backup_label

Recommended next steps:
  1. Put your preferred wallpaper at $WALLPAPER_DIR/default.png if it is not there yet.
  2. Reboot once so greetd auto-login and any NVIDIA changes take effect cleanly.
  3. After boot, Hyprland will start automatically on tty1.
  4. Press Super+Space to open the launcher.
  5. Press Super+D to toggle the dock.
  6. Press Super+Shift+W to randomize the wallpaper and regenerate the theme.

To apply your own wallpaper manually:
  ~/.local/bin/theme-apply /absolute/path/to/wallpaper.png

Notes:
  - Default scale is 1.75, defined in ~/.config/hypr/conf.d/00-monitors.conf.
  - Keyboard layout was set to '$KEYBOARD_LAYOUT'${KEYBOARD_VARIANT:+ with variant '$KEYBOARD_VARIANT'}.
  - GTK traffic-light buttons are best-effort styling, not a universal Linux guarantee.
  - Portals use Hyprland for compositor-specific features and GTK for FileChooser/OpenURI/Print.
  - greetd auto-logs into Hyprland once per boot; after logout it returns to a themed graphical gtkgreet login screen.
  - The greeter reuses the same wallpaper via shared state under /var/lib/hyprglass.
  - Bluetooth pairing and tray control are handled by Blueman.
EOF

  if (( NVIDIA_PRESENT == 1 )); then
    cat <<'EOF'
  - NVIDIA proprietary DKMS path was installed and prioritized deliberately on this machine.
  - Reboot after install so the DKMS modules, udev device symlinks, and mkinitcpio changes actually take effect.
  - On hybrid Intel+NVIDIA laptops this improves the chance of real NVIDIA rendering, but it also increases idle power draw and heat.
EOF
  fi

  printf '\n'
}

main() {
  require_not_root
  require_arch
  require_sudo
  validate_repo
  detect_gpus
  prompt_keyboard_config
  backup_existing
  install_packages
  deploy_files
  prepare_shared_greeter_assets
  configure_portals
  configure_nvidia
  configure_greetd
  enable_system_services
  enable_user_units
  apply_initial_theme
  post_install_validation
  print_next_steps
}

main "$@"
