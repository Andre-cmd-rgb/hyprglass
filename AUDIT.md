# hyprglass forensic audit

## Already good

- The project direction is coherent: Hyprland, hyprpaper, Waybar, Mako, Rofi, Kitty, dock, and matugen are all reasonable choices.
- The repo layout is GitHub-friendly and the source tree is modular.
- The installer already moved away from the most dangerous early mistake: deleting the entire `~/.config` tree.
- The project already distinguishes wallpaper generation from wallpaper ownership conceptually.
- The shell visuals are coherent enough to justify productizing the repo instead of treating it like throwaway dotfiles.

## Weak

- The installer was safer than before, but not strict enough about validating deprecated matugen syntax.
- NVIDIA handling existed only as a direction, not as a real machine-specific install/config path.
- The theme pipeline still relied on stale matugen assumptions.
- Runtime wallpaper state was not normalized to a managed path, so state was messy.

## Broken

- Hyprland input config contained removed gesture options.
- Hyprland active border colors were invalid because the generated palette fragment used `#hex` values where Hyprland expected proper color formats.
- Rofi generated theme syntax was invalid because identifiers contained underscores.
- Matugen config still contained deprecated `[config.custom_keywords]` and a wallpaper section that this project should not have used at all.
- Matugen templates still used `{{ custom.* }}` references that are no longer safe in this project.

## Outdated

- `windowrulev2` usage was left in place even though the repo should track current Hyprland syntax.
- `suppressevent` was outdated; current syntax is `suppress_event`.
- The gesture configuration used old option names.

## Risky

- NVIDIA was not being installed/configured in a way that guaranteed the proprietary DKMS path you explicitly wanted.
- The repo did not create a stable, explicit GPU priority fragment for multi-GPU Hyprland.
- The theme script would exit successfully with no wallpaper even when a user explicitly supplied a bad path.

## Inconsistent

- The intended architecture said hyprpaper owns wallpaper state, but the actual runtime flow still treated source paths loosely.
- The project claimed deterministic theming, but matugen invocation was not pinned to deterministic source color selection.
- The repo claimed productized behavior, but some configs still looked like intermediate chat-generated output.

## Prioritized fix plan

### Critical
- remove invalid Hyprland gesture options
- fix generated Hyprland color fragment to use valid color syntax
- fix generated Rofi syntax
- remove stale matugen config/features
- normalize wallpaper into a managed path

### High
- implement strict NVIDIA DKMS path and kernel-header handling
- generate machine-specific GPU config fragment
- harden installer validation and backup model
- modernize Hyprland rule syntax

### Medium
- tighten runtime reload behavior
- improve README and recovery story
- clarify tradeoffs in documentation

### Optional polish
- richer validation tooling for generated themes
- optional multi-profile monitor presets
- optional session mode for Intel-first vs NVIDIA-first hybrid behavior

## Final verdict

**Almost there, now materially improved.**

Before this audit, the project was **too fragile** to call production-ready because the visible parser errors were real and the NVIDIA path was incomplete.

After the corrections in this release, the project is **production-ready for the stated scope**: fresh Arch, Hyprland, modular repo, explicit NVIDIA handling, and a safe installer.

The remaining compromises are Linux compromises, not repo sloppiness:
- GTK decoration consistency is still best effort.
- NVIDIA-first on hybrid laptops still costs power and heat.
- Layer blur behavior still depends partly on client behavior.


## Additional release note

The login flow now uses `greetd` with automatic Hyprland start on boot and `gtkgreet` under a dedicated Hyprland greeter session after logout. Shared greeter assets live under `/var/lib/hyprglass` so wallpaper and greeter CSS stay aligned with the live desktop theme.
