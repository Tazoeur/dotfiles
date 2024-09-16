#!/bin/bash

set -eux

cd ./neovim
make CMAKE_BUILD_TYPE=RelWithDebInfo
make install
cd -
