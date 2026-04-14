# Unified Install And Raw Lifecycle Design

## Goal

Use `install.sh` as the only official install and migration entrypoint. On machines with pre-existing shell config, detect that state, show what will be backed up, and require user confirmation before applying managed dotfiles. Keep rollback and uninstall available through standalone raw GitHub commands.

## Scope

- Merge migration behavior into `install.sh`
- Preserve `scripts/migrate.sh` as a compatibility wrapper
- Add raw-friendly root wrappers for rollback and uninstall
- Update docs so lifecycle commands are available through `raw.githubusercontent.com`

## Behavior

`install.sh` keeps its existing local-checkout and archive bootstrap behavior. After the repository is available locally, the managed install flow checks for unmanaged shell state under `~/.zshrc`, `~/.config/starship.toml`, `~/.config/mise/`, `~/.config/zsh/`, and `~/.config/shell/secrets.zsh`.

If managed markers already exist, installation proceeds without a migration prompt. If unmanaged state is detected, the installer prints the backup location and paths it will preserve, then asks for confirmation unless `--yes` is supplied. Confirmed migrations reuse the existing backup and overlay seeding logic before running bootstrap.

## Compatibility

Existing `scripts/migrate.sh` callers continue to work by delegating to the unified install flow. Backup and rollback formats do not change.

## Testing

Add shell regression coverage for:

- install detecting unmanaged config and requiring confirmation
- install skipping migration on already-managed config
- compatibility wrapper calling the unified flow
- raw rollback and uninstall wrappers delegating to the local checkout
