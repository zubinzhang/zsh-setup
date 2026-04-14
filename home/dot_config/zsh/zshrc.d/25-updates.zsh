typeset -g ZSH_SETUP_UPDATE_STATUS="unknown"
typeset -g ZSH_SETUP_UPDATE_CHECKED_AT=0
typeset -g ZSH_SETUP_UPDATE_LOCAL_REV=""
typeset -g ZSH_SETUP_UPDATE_REMOTE_REV=""
typeset -g ZSH_SETUP_UPDATE_BRANCH=""
typeset -g ZSH_SETUP_UPDATE_PROMPTED_THIS_SHELL=0

_zsh_setup_run_update_check() {
  local ttl now cache_file prompt_file prompted_rev answer

  if ! command -v zsh-setup-check-updates >/dev/null 2>&1; then
    return
  fi

  ttl="${ZSH_SETUP_UPDATE_TTL_SECONDS:-3600}"
  now="${EPOCHSECONDS:-0}"
  cache_file="${ZSH_SETUP_STATE_HOME}/updates/status.env"
  prompt_file="${ZSH_SETUP_STATE_HOME}/updates/last-prompted-rev"

  mkdir -p "${ZSH_SETUP_STATE_HOME}/updates"
  eval "$(zsh-setup-check-updates --cache 2>/dev/null || true)"

  if [[ "${ZSH_SETUP_UPDATE_STATUS}" == "available" && "${ZSH_SETUP_UPDATE_REMOTE_REV}" != "" && "${ZSH_SETUP_UPDATE_PROMPTED_THIS_SHELL}" -eq 0 ]]; then
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
  fi

  if (( now - ZSH_SETUP_UPDATE_CHECKED_AT >= ttl )); then
    ( zsh-setup-check-updates --refresh >/dev/null 2>&1 ) &!
  fi
}

_zsh_setup_run_update_check
