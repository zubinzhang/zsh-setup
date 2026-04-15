# Zsh Plugin Runtime Design

## Goal

Complete the repository's managed integration for `zsh-autosuggestions` and `zsh-syntax-highlighting` so install, runtime loading, documentation, and regression coverage all describe the same behavior.

## Scope

- Keep the existing plugin discovery pattern based on known system and local data paths
- Keep dependency installation policy as package manager first, then `git clone` into `~/.local/share`
- Add conservative default runtime configuration for `zsh-autosuggestions`
- Document managed plugin behavior in the README
- Add regression coverage that protects plugin load order and default configuration

## Non-Goals

- Introduce a dedicated plugin manager
- Pin or vendor third-party plugin versions
- Add custom widgets or non-default keybinding behavior
- Fail shell startup when optional plugins are unavailable

## Runtime Design

`~/.config/zsh/zshrc.d/20-integrations.zsh` remains the integration module for shell enhancements. It should continue sourcing optional integrations after `mise activate zsh` so plugin code sees the final command environment.

`zsh-autosuggestions` loads before `zsh-syntax-highlighting`. This preserves the established ordering requirement between the two plugins and avoids visual or widget conflicts caused by sourcing syntax highlighting too early.

If either plugin is absent from all known paths, startup should continue silently. The shell remains functional without suggestions or highlighting, matching the repository's current approach for optional enhancements.

## Plugin Discovery

Runtime discovery continues to search these locations in order:

- Homebrew install paths under `/opt/homebrew/share` and `/usr/local/share`
- Common system package paths under `/usr/share`
- Repository-managed fallback clones under `${XDG_DATA_HOME:-$HOME/.local/share}`

This order keeps system package manager installs authoritative while preserving a self-managed fallback when package installation is unavailable.

## Autosuggestions Defaults

The repository should define a small set of conservative defaults before sourcing `zsh-autosuggestions`:

- a subdued suggestion highlight style that stays visually distinct from prompt text
- asynchronous suggestion fetching when the plugin supports it
- no custom accept widgets or keybinding remaps beyond plugin defaults

Defaults must be override-friendly. The managed config should only assign a default when the variable is currently unset so users can replace behavior in `~/.config/zsh/local/*.zsh` without editing managed files.

## Installation Design

`scripts/install-shell-deps.sh` remains the only installer entrypoint for these plugins. The installer should:

1. detect whether a plugin already exists in any known runtime path
2. try Homebrew or the available system package manager first
3. fall back to a shallow `git clone` into `${XDG_DATA_HOME:-$HOME/.local/share}/<plugin-name>`

The autosuggestions and syntax-highlighting installers should follow the same strategy and path layout so runtime discovery and installer behavior stay aligned.

## Documentation

The README should describe both plugins as managed optional shell enhancements. It should make three behaviors explicit:

- this repository configures autosuggestions and syntax highlighting as part of the managed zsh environment
- installation prefers system packages and falls back to local clones under `~/.local/share`
- if a plugin is missing, shell startup continues without that enhancement

## Testing

Add shell regression coverage for:

- `20-integrations.zsh` containing both plugin discovery loops
- `zsh-autosuggestions` appearing before `zsh-syntax-highlighting`
- autosuggestions default assignments being present and override-friendly
- installer behavior remaining aligned with the runtime fallback path layout

The tests should validate the managed files directly rather than requiring the third-party plugins to be installed in CI.
