autoload -Uz add-zsh-hook

typeset -g ZSH_SETUP_KUBE_PROMPT=""
typeset -g ZSH_SETUP_KUBE_STYLE=""
typeset -g ZSH_SETUP_KUBE_LAST_REFRESH=0

_zsh_setup_refresh_kube_prompt() {
  local ttl now
  ttl="${ZSH_SETUP_KUBE_TTL_SECONDS:-5}"
  now="${EPOCHSECONDS:-0}"

  if (( now - ZSH_SETUP_KUBE_LAST_REFRESH < ttl )); then
    return
  fi
  ZSH_SETUP_KUBE_LAST_REFRESH="${now}"

  if ! command -v zsh-setup-kube-prompt >/dev/null 2>&1; then
    unset ZSH_SETUP_KUBE_CONTEXT ZSH_SETUP_KUBE_NAMESPACE ZSH_SETUP_KUBE_PROMPT ZSH_SETUP_KUBE_STYLE
    return
  fi

  eval "$(zsh-setup-kube-prompt)"
}

add-zsh-hook precmd _zsh_setup_refresh_kube_prompt
