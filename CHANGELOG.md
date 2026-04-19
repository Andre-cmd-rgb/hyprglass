## 1.5.0

- switched default file manager from Thunar to Nautilus (GNOME Files) for a more polished GTK look
- added GNOME Calculator as the default calculator, bound to Super+C and the XF86Calculator media key
- added GNOME Settings (gnome-control-center) bound to Super+S for integrated system configuration
- added Hyprland float rules for Nautilus, GNOME Calculator, and GNOME Settings
- replaced thunar/thunar-archive-plugin in the installer package list with nautilus/gnome-calculator/gnome-control-center (file-roller retained for archive handling)

## 1.4.2

- fixed Nvidia open-driver removal so installer no longer aborts when only one open package is installed
- restored dedicated Waybar network and Bluetooth glyph modules
- switched Waybar Wi-Fi launcher to Impala directly
- added iwd package for Impala-based Wi-Fi management

## 1.4.0

- removed the dock from the default product build
- removed workspace indicators plus Wi-Fi/Bluetooth clutter from the top bar
- tightened Waybar spacing and kept only the active window title on the left
- cleaned GTK app styling for a more consistent rounded dark look
- kept the default scale at 1.67

## 1.3.3

- fixed greetd asset preparation on systems where the `greeter` user/group did not already exist
- fixed greetd config generation for the graphical logout greeter path
- ensured the installer removes `nvidia-open` / `nvidia-open-dkms` before installing the proprietary `nvidia-dkms` path

# Changelog

## 1.3.2
- Switched default monitor scale to 1.67.
- Fixed nwg-dock-hyprland stylesheet path handling by generating ~/.config/nwg-dock-hyprland/style.css and using relative style lookup.
- Added tracked nwg-dock-hyprland config directory so installs stay consistent.

## 1.3.0

- switched the login flow to greetd + gtkgreet with automatic Hyprland start on boot and a graphical greeter after logout
- added shared greeter assets under /var/lib/hyprglass so the greeter uses the same wallpaper as the desktop
- added generated gtkgreet CSS theming and fallback styling
- kept default monitor scale at 1.75

# Changelog

## 1.2.0

- switched the default monitor scale to 1.75 for denser 4K 16-inch laptop use
- added machine-specific keyboard layout detection plus installer prompt and local override fragment
- added greetd + tuigreet integration so Hyprland auto-starts on boot and falls back to a greeter after logout
- modernized shipped window rules to current Hyprland block syntax
- removed the unnecessary LIBVA NVIDIA env default from the generated GPU fragment

## 1.1.0

- fixed current Hyprland gesture syntax and removed invalid options
- fixed generated Hyprland palette output so border gradients use valid color syntax
- fixed generated Rofi color file syntax by removing invalid underscore identifiers
- removed deprecated matugen wallpaper ownership and custom keyword assumptions
- hardened `theme-apply` around managed wallpaper normalization and deterministic source color selection
- added NVIDIA proprietary DKMS install/config path with kernel header detection and Hyprland GPU fragment generation
- improved installer validation, backup scope, and machine-specific system file handling
