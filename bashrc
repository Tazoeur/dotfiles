source "$HOME/.dotfiles/bash/oh-my-bash.sh"

# add paths to PATH
source "$HOME/.dotfiles/bash/path.sh"

# Manage ssh agent and stuff
source "$HOME/.dotfiles/bash/ssh.sh"

# add some git stuff
source "$HOME/.dotfiles/bash/git.sh"

# Program-specific tweaks
source "$HOME/.dotfiles/bash/rust.sh"
source "$HOME/.dotfiles/bash/nvm.sh"
source "$HOME/.dotfiles/bash/fzf.sh"

# Completion and keybindings
source "$HOME/.dotfiles/bash/completion.sh"
source "$HOME/.dotfiles/bash/keybinding.sh"

# User defined aliases
source "$HOME/.dotfiles/bash/aliases.sh"
source "$HOME/.dotfiles/bash/docker-aliases.sh"
. "$HOME/.cargo/env"

set -o vi
bind -m vi-command ".":insert-last-argument
bind -m vi-insert "\C-l.":clear-screen
bind -m vi-insert "\C-w.":backward-kill-word

# Load pyenv automatically
if [ -f $HOME/.pyenv ]; then
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
# Load pyenv-virtualenv automatically
eval "$(pyenv virtualenv-init -)"
fi

# pip bash completion start
_pip_completion()
{
    COMPREPLY=( $( COMP_WORDS="${COMP_WORDS[*]}" \
                   COMP_CWORD=$COMP_CWORD \
                   PIP_AUTO_COMPLETE=1 $1 2>/dev/null ) )
}
complete -o default -F _pip_completion pip
# pip bash completion end

if [ "$TERM" = "tmux-256color" ]; then
	/bin/echo -e "
	\e]P0#191724
	\e]P1#eb6f92
	\e]P2#9ccfd8
	\e]P3#f6c177
	\e]P4#31748f
	\e]P5#c4a7e7
	\e]P6#ebbcba
	\e]P7#e0def4
	\e]P8#26233a
	\e]P9#eb6f92
	\e]PA#9ccfd8
	\e]PB#f6c177
	\e]PC#31748f
	\e]PD#c4a7e7
	\e]PE#ebbcba
	\e]PF#e0def4
	"
	# get rid of artifacts
	clear
fi

if [ -d ~/.spicetify ]; then
    export PATH=$PATH:~/.spicetify
fi
