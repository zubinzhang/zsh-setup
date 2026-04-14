# Unified Install And Raw Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge migration into the main install entrypoint while keeping rollback and uninstall available as standalone raw commands.

**Architecture:** Keep `install.sh` responsible for repo acquisition only, then delegate local lifecycle behavior to repo scripts. Add a shared migration-detection layer in `scripts/`, preserve compatibility with the old migrate path, and expose root wrapper scripts for raw GitHub usage.

**Tech Stack:** Bash, zsh, chezmoi, mise, shell regression tests

---

### Task 1: Lock Behavior With Tests

**Files:**
- Modify: `tests/test_shell_env.sh`

- [ ] **Step 1: Write the failing tests**

Add tests covering:

```bash
test_install_prompts_before_migrating_existing_config
test_install_skips_migration_prompt_for_managed_state
test_migrate_wrapper_delegates_to_install_flow
test_raw_rollback_wrapper_delegates_to_local_script
test_raw_uninstall_wrapper_delegates_to_local_script
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `bash tests/run.sh`
Expected: new tests fail because the unified flow and raw wrappers do not exist yet.

### Task 2: Implement Unified Install Flow

**Files:**
- Modify: `install.sh`
- Modify: `scripts/migrate.sh`
- Modify: `scripts/lib/common.sh`
- Create: `scripts/install-managed.sh`
- Create: `rollback.sh`
- Create: `uninstall.sh`

- [ ] **Step 1: Add shared migration detection and confirmation helpers**

Implement helpers for:

```bash
is_managed_install
has_existing_shell_state
confirm_migration
```

- [ ] **Step 2: Add a local managed-install entrypoint**

Implement `scripts/install-managed.sh` so it:

```bash
detects managed vs unmanaged state
backs up and seeds overlays when migration is confirmed
runs bootstrap after confirmation
```

- [ ] **Step 3: Make `install.sh` call the local managed-install flow**

Keep archive/bootstrap acquisition intact, but replace direct bootstrap execution with:

```bash
exec "${base}/scripts/install-managed.sh" "$@"
```

- [ ] **Step 4: Keep compatibility wrappers thin**

Make `scripts/migrate.sh`, `rollback.sh`, and `uninstall.sh` delegate to the canonical local scripts.

- [ ] **Step 5: Run tests to verify green**

Run: `bash tests/run.sh`
Expected: PASS

### Task 3: Update Docs

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Update lifecycle docs**

Document raw commands for:

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/rollback.sh | bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/uninstall.sh | bash
```

- [ ] **Step 2: Run final verification**

Run:

```bash
bash tests/run.sh
bash -n install.sh rollback.sh uninstall.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync
shellcheck install.sh rollback.sh uninstall.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync
shfmt -d install.sh rollback.sh uninstall.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync
PATH="$HOME/.local/share/mise/installs/chezmoi/latest:$PATH" bash scripts/ci-smoke-apply.sh
```
Expected: all commands succeed.
