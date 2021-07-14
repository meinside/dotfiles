#!/usr/bin/env bash

# install_haskell.sh
#
# Install haskell and its tools.
# 
# created on : 2021.07.12.
# last update: 2021.07.14.
# 
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

TMP_DIR="/tmp"
OPT_DIR="/opt"

# NOTE: working fine on x64 with Ubuntu 20.04 LTS
# NOTE: fails to install hls and stack on Raspberry Pi 4 with Ubuntu 21.04 (updated: 2021.07.14.)
# NOTE: totally fails on Raspberry Pi 4 with RPiOS 64bit beta (updated: 2021.07.14.)
function install_linux {
	echo -e "${YELLOW}>>> installing essential packages ...${RESET}"
	sudo apt-get install -y build-essential curl libffi-dev libffi7 libgmp-dev libgmp10 libncurses-dev libncurses5 libtinfo5

	echo -e "${YELLOW}>>> installing ghcup ...${RESET}"
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
}

function install_macos {
	echo -e "${YELLOW}>>> installing ghcup ...${RESET}"
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

