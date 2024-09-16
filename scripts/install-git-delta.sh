#!/bin/bash

set -eux

GIT_DELTA_VERSION=$(curl -Ls "https://github.com/dandavison/delta/releases/latest" | grep -Po 'https://github.com/dandavison/delta/releases/tag/\K[^"]*' | head -n 1)
curl -Lo /tmp/git-delta.deb "https://github.com/dandavison/delta/releases/latest/download/git-delta_${GIT_DELTA_VERSION}_amd64.deb"
dpkg -i /tmp/git-delta.deb
rm -f /tmp/git-delta.deb
