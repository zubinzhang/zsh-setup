mkdir -p "${ZSH_SETUP_CACHE_HOME}" "${ZSH_SETUP_CACHE_HOME}/completions"
fpath=("${ZSH_SETUP_CACHE_HOME}/completions" $fpath)

autoload -Uz compinit
compinit -d "${ZSH_SETUP_CACHE_HOME}/zcompdump-${HOST}-${ZSH_VERSION}"
