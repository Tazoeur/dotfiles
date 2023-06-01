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

# Grep
alias grep="grep --color"

# batcat
alias cat="batcat --theme=Catppuccin-macchiato"

# load env variables
alias loadenv="[ -f .env ] && set -o allexport && source .env && set +o allexport"
