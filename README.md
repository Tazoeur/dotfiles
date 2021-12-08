# dotfiles
My dot files

## Install

```bash
# clone
git clone git@github.com:Tazoeur/dotfiles.git ~/.dotfiles && cd ~/.dotfiles

# bootstrap dotfiles
./install

# install packages
sudo ~/.dotfiles/install -p dotbot-apt/apt.py -c packages.conf.yaml
