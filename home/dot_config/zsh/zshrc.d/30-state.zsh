typeset -g ZSH_SETUP_UPDATE_STATUS="unknown"
typeset -g ZSH_SETUP_UPDATE_CHECKED_AT=0
typeset -g ZSH_SETUP_UPDATE_LOCAL_REV=""
typeset -g ZSH_SETUP_UPDATE_REMOTE_REV=""
typeset -g ZSH_SETUP_UPDATE_BRANCH=""
typeset -g ZSH_SETUP_UPDATE_PROMPTED_THIS_SHELL=0
typeset -g ZSH_SETUP_UPDATE_REFRESH_SCHEDULED=0

_zsh_setup_load_update_cache() {
  local cache_file="$1"

  if [[ -f "${cache_file}" ]]; then
    source "${cache_file}"
  else
    ZSH_SETUP_UPDATE_STATUS="unknown"
    ZSH_SETUP_UPDATE_BRANCH=""
    ZSH_SETUP_UPDATE_LOCAL_REV=""
    ZSH_SETUP_UPDATE_REMOTE_REV=""
    ZSH_SETUP_UPDATE_CHECKED_AT=0
  fi
}

_zsh_setup_maybe_prompt_update() {
  local cache_file="$1"
  local prompt_file="$2"
  local prompted_rev answer

  if [[ "${ZSH_SETUP_UPDATE_STATUS}" != "available" || "${ZSH_SETUP_UPDATE_REMOTE_REV}" == "" || "${ZSH_SETUP_UPDATE_PROMPTED_THIS_SHELL}" -ne 0 ]]; then
    return
  fi

  prompted_rev=""
  [[ -f "${prompt_file}" ]] && prompted_rev="$(<"${prompt_file}")"
  if [[ "${prompted_rev}" != "${ZSH_SETUP_UPDATE_REMOTE_REV}" && -t 0 && -t 1 ]]; then
    ZSH_SETUP_UPDATE_PROMPTED_THIS_SHELL=1
    printf '[zsh-setup] Dotfiles update available on %s. Upgrade now? [y/N] ' "${ZSH_SETUP_UPDATE_BRANCH:-main}"
    read -r answer
    if [[ "${answer}" == [Yy] || "${answer}" == [Yy][Ee][Ss] ]]; then
      if zsh-setup-sync; then
        rm -f "${cache_file}" "${prompt_file}"
      else
        printf '[zsh-setup] Upgrade failed. Run zsh-setup-sync manually after resolving the issue.\n' >&2
      fi
    else
      printf '%s\n' "${ZSH_SETUP_UPDATE_REMOTE_REV}" >| "${prompt_file}"
    fi
  fi
}

_zsh_setup_run_update_check() {
  local cache_file prompt_file

  if ! command -v zsh-setup-check-updates >/dev/null 2>&1; then
    return
  fi

  cache_file="${ZSH_SETUP_STATE_HOME}/updates/status.env"
  prompt_file="${ZSH_SETUP_STATE_HOME}/updates/last-prompted-rev"

  mkdir -p "${ZSH_SETUP_STATE_HOME}/updates"
  _zsh_setup_load_update_cache "${cache_file}"
  _zsh_setup_maybe_prompt_update "${cache_file}" "${prompt_file}"
}

_zsh_setup_schedule_update_refresh() {
  local ttl now

  if ! command -v zsh-setup-check-updates >/dev/null 2>&1; then
    return
  fi

  if (( ZSH_SETUP_UPDATE_REFRESH_SCHEDULED != 0 )); then
    return
  fi

  ttl="${ZSH_SETUP_UPDATE_TTL_SECONDS:-3600}"
  now="${EPOCHSECONDS:-0}"
  if (( now - ZSH_SETUP_UPDATE_CHECKED_AT < ttl )); then
    return
  fi

  ZSH_SETUP_UPDATE_REFRESH_SCHEDULED=1
  ( zsh-setup-check-updates --refresh >/dev/null 2>&1 ) &!
}

_zsh_setup_run_update_check
_zsh_setup_schedule_update_refresh

autoload -Uz add-zsh-hook

typeset -gx ZSH_SETUP_KUBE_PROMPT=""
typeset -gx ZSH_SETUP_KUBE_STYLE=""
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
