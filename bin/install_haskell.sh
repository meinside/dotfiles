#!/usr/bin/env bash

# install_haskell.sh
#
# Install haskell and its tools.
# 
# created on : 2021.07.12.
# last update: 2021.07.15.
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
	sudo apt-get install -y build-essential curl libffi-dev libffi7 libgmp-dev libgmp10 libncurses-dev libncurses5 libtinfo5 stylish-haskell

	echo -e "${YELLOW}>>> installing ghcup ...${RESET}"
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
}

function install_macos {
	echo -e "${YELLOW}>>> installing ghcup ...${RESET}"
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

	echo -e "${YELLOW}>>> installing stylish-haskell ...${RESET}"
	LATEST_ZIP=`curl -s "https://api.github.com/repos/haskell/stylish-haskell/releases" | grep "https" | grep "darwin" | grep "$PLATFORM" | cut -d \" -f4 | head -n 1`
	STYLISH_HASKELL_BIN="$HOME/.ghcup/bin/stylish-haskell"
	DOWNLOADED_ZIP="$STYLISH_HASKELL_BIN".zip
	wget -O $DOWNLOADED_ZIP $LATEST_ZIP && \
		unzip -j $DOWNLOADED_ZIP "*/stylish-haskell" && \
		chmod +x $STYLISH_HASKELL_BIN && \
		rm $DOWNLOADED_ZIP
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

