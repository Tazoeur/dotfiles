# Custom programs
alias playground="/opt/scripts/playground.sh"
alias pdfmerge="/opt/scripts/pdfmerger/pdfmerger.sh"

# Editors
alias vim=nvim
alias vi=nvim
alias v=nvim

# ls
alias l="ls -lAh"
alias la="ls -A"
alias ll="ls -l"

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
alias bat="batcat"

# load env variables
alias loadenv="[ -f .env ] && set -o allexport && source .env && set +o allexport"

# dfimage
alias dfimage="docker run -v /var/run/docker.sock:/var/run/docker.sock --rm ghcr.io/laniksj/dfimage"

# ---- Eza (better ls) -----
alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"


export BAT_THEME=rose-pine
