alias claude='claude --dangerously-skip-permissions'

# gitcd: clone a repo and cd into it (equivalent to viko16/gitcd.plugin.zsh)
# Usage: gitcd <repo-url>
# Config: GITCD_HOME (default: ~/Code), GITCD_USEHOST (default: true)
function gitcd() {
  local repo_url="$1"
  if [[ -z "$repo_url" ]]; then
    echo "Usage: gitcd <repo-url>" >&2
    return 1
  fi

  local base="${GITCD_HOME:-$HOME/workspace}"

  # Normalize URL: strip protocol, convert git@host:path to host/path, strip .git
  local normalized="${repo_url#https://}"
  normalized="${normalized#http://}"
  normalized="${normalized%.git}"
  normalized="${normalized/://}"   # git@github.com:user/repo -> git@github.com/user/repo
  normalized="${normalized#*@}"    # git@github.com/user/repo -> github.com/user/repo

  local target
  if [[ "${GITCD_USEHOST:-true}" == "false" ]]; then
    target="$base/${normalized#*/}"
  else
    target="$base/$normalized"
  fi

  if [[ -d "$target" ]]; then
    cd "$target"
  else
    mkdir -p "$(dirname "$target")" && git clone "$repo_url" "$target" && cd "$target"
  fi
}

# git aliases (equivalent to oh-my-zsh git plugin)
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gc='git commit --verbose'
alias gc!='git commit --verbose --amend'
alias gca='git commit --verbose --all'
alias gcb='git checkout -b'
alias gco='git checkout'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git pull'
alias glog='git log --oneline --decorate --graph'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase -i'
alias gst='git status'
alias gsw='git switch'
alias gswc='git switch -c'

# ls aliases — prefer eza for richer file/dir distinction
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --icons --group-directories-first'
  alias la='eza -lah --icons --group-directories-first'
  alias lt='eza --tree --icons --group-directories-first'
elif [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -G'
  alias ll='ls -lhG'
  alias la='ls -lahG'
else
  alias ls='ls --color=auto'
  alias ll='ls -lh --color=auto'
  alias la='ls -lah --color=auto'
fi

# Reload zshrc without reopening terminal
alias reload='source "$HOME/.zshrc" && echo "reloaded"'
