if (( $(ls ~/.local/share/fonts/Hack* | wc -l) > 1 ));then
	echo "Fonts are already present, skipping."
	exit 0
fi
mkdir /tmp/fonts
cp "$HOME/.dotfiles/fonts/Hack.zip" /tmp/fonts
# unzip Hack.zip
cd /tmp/fonts
unzip Hack.zip
rm Hack.zip
# move .ttf to ~/.local/share/fonts
if [ ! -d ~/.local/share/fonts ]; then
	mkdir -p ~/.local/share/fonts
fi
mv Hack* ~/.local/share/fonts
# update font cache
fc-cache -f
