# Install State And Mise Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix local install semantics so the repo applies a valid managed shell, remove duplicate `mise` runtime installs for `chezmoi` and `gh`, and tighten verification around managed shell ownership.

**Architecture:** Local bootstrap will treat the installed repo checkout as the canonical source and apply `home/` directly with `chezmoi apply`. Runtime helpers that need the managed source will resolve it from the install home instead of global chezmoi state. User-level `mise` config and `doctor` checks will be tightened accordingly.

**Tech Stack:** Bash, zsh, chezmoi, mise, shell regression tests

---

### Task 1: Lock The Broken Cases With Tests

**Files:**
- Modify: `tests/test_shell_env.sh`

- [ ] **Step 1: Write the failing tests**

Add tests covering:

```bash
test_bootstrap_uses_apply_for_local_home_source
test_sync_uses_installed_home_source_without_chezmoi_source_path
test_check_updates_uses_installed_home_source_without_chezmoi_source_path
test_managed_mise_config_excludes_chezmoi_and_gh
test_doctor_requires_managed_zshrc_marker
```

- [ ] **Step 2: Run the regression suite to verify red**

Run: `bash tests/run.sh`
Expected: new tests fail because bootstrap, update helpers, managed `mise`, and doctor still follow the old behavior.

### Task 2: Fix Install Source Resolution

**Files:**
- Modify: `scripts/bootstrap.sh`
- Modify: `scripts/sync.sh`
- Modify: `scripts/check-updates.sh`
- Modify: `home/dot_local/bin/executable_zsh-setup-sync`
- Modify: `home/dot_local/bin/executable_zsh-setup-check-updates`
- Modify: `scripts/lib/common.sh`

- [ ] **Step 1: Add a shared helper for resolving the installed repo home source**

Implement a helper that returns:

```bash
${ZSH_SETUP_HOME:-$HOME/.local/share/zsh-setup}/home
```

and validates that the directory exists when commands require it.

- [ ] **Step 2: Make local bootstrap use `chezmoi apply --source=...`**

Keep repo-URL initialization for the remote path, but change the local installed-checkout path to apply the existing `home/` tree directly.

- [ ] **Step 3: Make sync and startup update checks use the installed repo path**

Remove reliance on `chezmoi source-path` for the installed-checkout path and read Git state from the install repo checkout.

- [ ] **Step 4: Run tests to confirm green for these cases**

Run: `bash tests/run.sh`
Expected: the new source-resolution tests pass.

### Task 3: Fix Managed Runtime And Verification

**Files:**
- Modify: `home/dot_config/mise/config.toml`
- Modify: `scripts/doctor.sh`
- Modify: `README.md`

- [ ] **Step 1: Remove `chezmoi` and `gh` from the managed `mise` config**

Keep only:

```toml
[tools]
helm = "latest"
kubectl = "latest"
starship = "latest"
```

- [ ] **Step 2: Make doctor validate managed ownership**

Require the managed zshrc marker and keep the existing path checks.

- [ ] **Step 3: Update docs**

Document that bootstrap installs `chezmoi` itself, while user-level `mise` manages `starship`, `kubectl`, and `helm`.

- [ ] **Step 4: Run full verification**

Run:

```bash
bash tests/run.sh
bash -n install.sh rollback.sh uninstall.sh sync.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync
zsh -n home/dot_zshrc home/dot_config/zsh/zshrc.d/*.zsh
~/.local/share/mise/installs/shellcheck/latest/shellcheck-v0.11.0/shellcheck install.sh rollback.sh uninstall.sh sync.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync
~/.local/share/mise/installs/shfmt/latest/shfmt -d install.sh rollback.sh uninstall.sh sync.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync
PATH="$HOME/.local/share/mise/installs/chezmoi/latest:$PATH" bash scripts/ci-smoke-apply.sh
```

Expected: all commands succeed.
