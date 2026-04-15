# One-Shot Shell Bootstrap Design

## Goal

Upgrade the repository so `install.sh` can take a fresh macOS or Linux machine to a usable managed zsh environment in one run, including core tool installation, managed config rendering, compinit safety repair, optional macOS iTerm2 font integration, and startup performance tuning.

## Scope

- Keep `install.sh` as the only official install entrypoint
- Support fresh-install bootstrap for macOS and Linux
- Auto-install `mise`, `starship`, `eza`, and the managed zsh plugins used by this repo
- Auto-install a single repo-approved Nerd Font family
- Auto-render `~/.zshrc` and modular `~/.config/zsh/zshrc.d/` via `chezmoi`
- Auto-repair directories that would cause `compinit` / `compaudit` startup prompts
- Offer optional iTerm2 Nerd Font setup on macOS
- Preserve idempotent behavior on repeated runs
- Improve startup cost through lazy initialization and cache-aware runtime setup

## Non-Goals

- Replace `chezmoi` with a different dotfiles manager
- Introduce a third-party zsh framework or plugin manager
- Force a terminal emulator theme, color scheme, or window layout
- Force iTerm2 usage on macOS or a specific terminal on Linux
- Manage every possible shell utility beyond the tools this repo explicitly depends on

## Architectural Direction

The existing `install.sh` + `scripts/` + `chezmoi home/` layout remains the system boundary. The change is not a new installer architecture; it is a stronger orchestration layer on top of the existing one.

`install.sh` stays responsible for obtaining or refreshing the local repository and delegating to the managed install flow. The managed install flow becomes responsible for executing a full bootstrap pipeline that can safely run on both empty and partially managed machines.

The pipeline should remain phase-oriented and idempotent. Each phase must be safe to re-run independently and should only mutate the files or directories it owns.

## Bootstrap Phases

### Phase 1: Environment Detection

The installer should gather a single shared runtime context before making changes:

- OS family: macOS or Linux
- architecture
- available package managers
- current shell and `zsh` availability
- user config, cache, state, and data homes
- font install destination
- whether iTerm2 appears available on macOS

This phase should only detect and decide. It should not write user config.

### Phase 2: Core Dependencies

The bootstrap should install the core tools this repository expects:

- `mise`
- `starship`
- `eza`
- `chezmoi` as a bootstrap dependency

It should also install the managed zsh enhancements already supported by the runtime:

- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- `zsh-completions`

Dependency strategy should stay consistent with current repository behavior:

- prefer Homebrew on macOS
- prefer the available system package manager on Linux
- use a repository-controlled fallback when a package manager path is unavailable

The plugin fallback remains shallow clones under `~/.local/share`.

### Phase 3: Nerd Font Installation

The bootstrap should manage exactly one approved Nerd Font family to avoid font sprawl. Installation should target user-scoped font directories:

- macOS: user font directory recognized by the system
- Linux: user font directory under XDG/home conventions

The installer must detect whether the font is already present and skip reinstallation when possible. Repeated runs must not duplicate files or create name-suffixed font clutter.

### Phase 4: Managed Config Rendering

Configuration remains `chezmoi`-driven:

- render `~/.zshrc`
- render modular `~/.config/zsh/zshrc.d/`
- render supporting managed files under `~/.config` and `~/.local/bin`

Existing migration and backup behavior should continue to protect pre-existing user config. Fresh installs and migrations must still flow through the same top-level entrypoint.

### Phase 5: Compinit Safety Repair

The installer should proactively repair the directories that would otherwise trigger `compaudit` / `compinit` interactive failures at first shell launch.

This repair must be narrow and evidence-based:

- inspect the completion and shared-data paths the managed zsh config actually uses
- fix ownership and permissions only where needed
- avoid broad recursive permission rewrites outside the managed dependency footprint

The target outcome is that a fresh interactive shell no longer stops on the insecure-directory prompt during normal startup.

### Phase 6: Terminal Integration

Terminal integration should stay minimal and optional.

On macOS:

- detect whether iTerm2 is installed
- optionally set the configured profile font to the managed Nerd Font
- avoid changing colors, keybindings, or layout

On Linux:

- do not write terminal-specific configuration by default
- keep the shell usable without requiring terminal integration

### Phase 7: Runtime Performance

Runtime startup should prefer lazy and cache-aware behavior:

- keep completions cached and refresh them only when required
- avoid expensive command discovery on every prompt render
- initialize heavyweight integrations only when their commands or state are relevant
- keep all caches rebuildable from managed state

Performance optimization must not rely on stale state that silently breaks behavior. If a cache is invalid, it should be recreated automatically.

## Prompt And Shell Experience

The managed result after installation should be a usable shell experience out of the box:

- modular zsh config
- prompt styling aligned with the repository's managed Starship configuration
- managed history behavior, including prefix-based arrow search when configured
- optional plugin enhancements that degrade gracefully when unavailable

The installer is responsible for getting the environment to the point where these managed runtime features can actually work on first launch.

## Idempotency Requirements

Repeated executions of `install.sh` must converge instead of accumulating side effects.

Specifically:

- already-installed tools should be skipped cleanly
- already-present fonts should not be reinstalled
- already-rendered config should be updated in place, not duplicated
- repaired permissions should remain stable
- optional integrations should not reapply endlessly when no change is needed

Idempotency also means failure should leave the environment in a recoverable state. Partial success must not corrupt pre-existing user config.

## Failure Handling

Bootstrap work should distinguish between required and optional outcomes.

Required:

- repository acquisition
- `chezmoi` availability
- managed config rendering
- core shell usability

Optional but desirable:

- Nerd Font install
- iTerm2 font wiring
- non-critical plugin installs that can degrade gracefully

Optional step failures should be reported clearly but should not prevent the user from getting a working managed shell when the core path succeeded.

Rollback and uninstall behavior must remain compatible with the repository's existing lifecycle design.

## Testing Strategy

Add regression coverage for:

- macOS and Linux package-manager selection
- fallback installation of repo-managed plugin sources
- user-scoped Nerd Font installation and idempotent re-run behavior
- `compinit` safety repair for known insecure shared-data/completion directories
- generated managed zsh module layout
- optional iTerm2 integration behavior on macOS
- repeated install runs producing stable results
- startup/runtime checks for lazy or cached behavior where the repository explicitly depends on it

Tests should prefer shell-level end-to-end behavior using the repository's existing shell test harness, with narrow fakes for external commands where needed.

## User-Visible Outcome

After a successful fresh install, a user on macOS or Linux should be able to open a new terminal and get:

- a working managed zsh session
- no first-run `compinit` security prompt
- installed core tooling required by the repo's shell UX
- a Nerd Font available for prompt glyphs
- prompt and shell behavior that match the managed config
- safe re-runs of `install.sh` without environment drift
