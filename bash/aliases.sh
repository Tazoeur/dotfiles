# Custom programs
alias playground="/opt/scripts/playground.sh"
alias pdfmerge="/opt/scripts/pdfmerger/pdfmerger.sh"

# Editors
alias vim=nvim
alias vi=nvim
alias v=nvim


# Git
alias lg="lazygit"

git-remove-merged () {
  git fetch --prune
  merged_branches=$(git branch --format "%(refname:short)" --merged | grep -v master | grep -v main | grep -v develop)
  for b in $merged_branches; do
    git branch -d $b;
  done
  echo "No more merged branch to clean in your local repo"
}

# Grep
alias grep="grep --color"

# batcat
alias cat="bat"

# load env variables
alias loadenv="[ -f .env ] && set -o allexport && source .env && set +o allexport"

# dfimage
alias dfimage="docker run -v /var/run/docker.sock:/var/run/docker.sock --rm ghcr.io/laniksj/dfimage"

# ---- Eza (better ls) -----
alias ls="eza --color=always  --git  --icons=always --oneline"
alias ll="ls -lAh"
alias l="ll"
alias la="ls -A"
alias lt="ls --tree -L 2"


export BAT_THEME=rose-pine
