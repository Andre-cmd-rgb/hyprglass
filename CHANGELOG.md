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
