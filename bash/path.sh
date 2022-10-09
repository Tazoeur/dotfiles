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
