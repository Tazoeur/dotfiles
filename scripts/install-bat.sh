#!/bin/bash

set -eux

BAT_VERSION=$(curl -s "https://api.github.com/repos/sharkdp/bat/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo /tmp/bat.deb "https://github.com/sharkdp/bat/releases/latest/download/bat_${BAT_VERSION}_amd64.deb"
dpkg -i /tmp/bat.deb
rm -f /tmp/bat.deb
