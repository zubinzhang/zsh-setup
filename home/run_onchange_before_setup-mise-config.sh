#!/usr/bin/env bash
# chezmoi run_onchange_: re-runs whenever this file's content changes.
# Writes mise global config without chezmoi tracking the destination file,
# avoiding the "has changed since chezmoi last wrote it" interactive prompt.

# mise-tools: helm=latest kubectl=latest starship=latest

set -euo pipefail

MISE_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/mise/config.toml"
mkdir -p "$(dirname "${MISE_CONFIG}")"

cat > "${MISE_CONFIG}" << 'EOF'
[tools]
helm = "latest"
kubectl = "latest"
starship = "latest"
EOF
