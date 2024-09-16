local_bin="$HOME/.local/bin"
if [ -d $local_bin ]; then
  export PATH="$PATH:$local_bin"
fi

go_bin="/usr/local/go/bin"
if [ -d $go_bin ]; then
	export PATH="$PATH:$go_bin"
fi

poetry_bin="/home/taz/local/bin"
if [ -d $poetry_bin ]; then
	export PATH="$PATH:$poetry_bin"
fi

if [ -d "$HOME/.bin/platform-tools" ] ; then
    PATH="$HOME/.bin/platform-tools:$PATH" 
fi
[ -f "/home/taz/.ghcup/env" ] && source "/home/taz/.ghcup/env" # ghcup-env
