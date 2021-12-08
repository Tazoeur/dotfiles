local_bin="$HOME/.local/bin"
if [ -d $local_bin ]; then
  export PATH="$PATH:$local_bin"
fi

export PATH="$PATH:/usr/local/go/bin"