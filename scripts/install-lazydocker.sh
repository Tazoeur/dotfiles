#!/bin/bash

set -eux

LAZYDOCKER_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo /tmp/lazydocker.tar.gz "https://github.com/jesseduffield/lazydocker/releases/latest/download/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz"
tar xf /tmp/lazydocker.tar.gz lazydocker
install lazydocker /usr/local/bin
rm -rf /tmp/lazydocker*
rm lazydocker
