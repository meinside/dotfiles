#!/usr/bin/env bash

# install_haskell.sh
#
# Install haskell and its tools.
# 
# created on : 2021.07.12.
# last update: 2021.07.12.
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

function install_linux {
	echo -e "${YELLOW}>>> installing with ghcup ...${RESET}"
	# TODO: not working on aarch64
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

	echo -e "${YELLOW}>>> installing haskell-language-server ...${RESET}"
	# TODO: not working on aarch64
	install_hls "Linux"
}

function install_macos {
	echo -e "${YELLOW}>>> installing stack ...${RESET}"
	brew install haskell-stack

	echo -e "${YELLOW}>>> updating/upgrading stack ...${RESET}"
	stack update && stack upgrade

	echo -e "${YELLOW}>>> installing haskell-language-server ...${RESET}"
	install_hls "macOS"
}

function install_hls {
	PLATFORM="$1"
	HLS_DIR="$OPT_DIR/hls"
	TAR_URL=$( curl -s https://api.github.com/repos/haskell/haskell-language-server/releases/latest | grep 'browser_' | cut -d\" -f4 | grep "$PLATFORM" | grep ".tar.gz" )

	sudo mkdir -p "$HLS_DIR" && \
		wget -qO- "$TAR_URL" | sudo tar -xzv -C "$HLS_DIR" && \
		sudo chown -R "$USER" "$HLS_DIR" && \
		sudo chmod +x $HLS_DIR/haskell-language-server-* && \
		echo -e "${GREEN}>>> Installed haskell-language-server in: ${HLS_DIR} ${RESET}"
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

