# Contributing

Thanks for considering a contribution.

## Scope

hyprglass is intentionally opinionated:
- Arch Linux only
- Hyprland only
- dark base + wallpaper-driven accents
- no power management features
- no "theme pack" sprawl

Contributions should improve stability, maintainability, or visual coherence without bloating the project.

## Good contributions

- fixing broken config or install logic
- improving documentation
- tightening GTK / Waybar / Rofi consistency
- improving shell robustness and idempotency
- updating package or portal guidance when upstream changes

## Changes that will likely be rejected

- adding unrelated desktop components
- adding distro-agnostic abstraction layers
- adding battery or thermal management logic
- hardcoding a fixed color theme
- shipping massive dependency creep for minor visual tweaks

## Style

- Keep Bash readable and defensive.
- Prefer small focused scripts over giant multipurpose files.
- Preserve the modular config layout.
- Do not duplicate colors across components when they can be generated from the theme pipeline.
