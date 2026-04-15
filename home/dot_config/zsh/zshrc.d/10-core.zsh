HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=100000
SAVEHIST=100000
HIST_STAMPS="%F %T"

setopt append_history
setopt auto_cd
setopt extended_history
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_save_no_dups
setopt share_history

mkdir -p "${ZSH_SETUP_CACHE_HOME}" "${ZSH_SETUP_CACHE_HOME}/completions"
fpath=("${ZSH_SETUP_CACHE_HOME}/completions" $fpath)

# zsh-completions (must be added to fpath before compinit)
for _d in \
  /opt/homebrew/share/zsh-completions \
  /usr/local/share/zsh-completions \
  /usr/share/zsh/vendor-completions \
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh-completions/src"; do
  [[ -d "$_d" ]] && fpath=("$_d" $fpath)
done
unset _d

autoload -Uz compaudit compinit
zmodload zsh/stat 2>/dev/null || true
_zcompdump_file="${ZSH_SETUP_CACHE_HOME}/zcompdump-${HOST}-${ZSH_VERSION}"
typeset -a _zcompdump_mtime
_zsh_setup_fast_compinit=0

if whence -w zstat >/dev/null 2>&1 && [[ -f "${_zcompdump_file}" ]]; then
  zstat -A _zcompdump_mtime +mtime -- "${_zcompdump_file}" 2>/dev/null || _zcompdump_mtime=()
  if (( ${#_zcompdump_mtime[@]} == 1 && EPOCHSECONDS - _zcompdump_mtime[1] < ${ZSH_SETUP_COMPDUMP_MAX_AGE_SECONDS:-86400} )); then
    _zsh_setup_fast_compinit=1
  fi
fi

if (( _zsh_setup_fast_compinit )); then
  compinit -C -d "${_zcompdump_file}"
else
  _zsh_setup_insecure_compdirs=($(compaudit 2>/dev/null))
  if (( ${#_zsh_setup_insecure_compdirs[@]} > 0 )); then
    compinit -i -d "${_zcompdump_file}"
  else
    compinit -d "${_zcompdump_file}"
  fi
  unset _zsh_setup_insecure_compdirs
fi
unset _zcompdump_file _zcompdump_mtime _zsh_setup_fast_compinit

if command -v kubectl >/dev/null 2>&1; then
  [[ -f "${ZSH_SETUP_CACHE_HOME}/completions/_kubectl" ]] || \
    kubectl completion zsh > "${ZSH_SETUP_CACHE_HOME}/completions/_kubectl"
fi

if command -v helm >/dev/null 2>&1; then
  [[ -f "${ZSH_SETUP_CACHE_HOME}/completions/_helm" ]] || \
    helm completion zsh > "${ZSH_SETUP_CACHE_HOME}/completions/_helm"
fi

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

bindkey -M viins '^[[A' up-line-or-beginning-search
bindkey -M viins '^[[B' down-line-or-beginning-search
bindkey -M viins '^[OA' up-line-or-beginning-search
bindkey -M viins '^[OB' down-line-or-beginning-search
