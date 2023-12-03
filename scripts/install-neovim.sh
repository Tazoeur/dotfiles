#!/bin/bash

set -eux

cd ~/.dotfiles/neovim
make CMAKE_BUILD_TYPE=RelWithDebInfo
sudo make install
cd -
