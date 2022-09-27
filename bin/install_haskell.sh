#!/usr/bin/env bash

# install_haskell.sh
#
# Install haskell and its tools.
# 
# created on : 2021.07.12.
# last update: 2022.09.27.
# 
# by meinside@duck.com


################################
#
# common functions and variables

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# functions for pretty-printing
function error {
	echo -e "${RED}$1${RESET}"
}
function info {
	echo -e "${GREEN}$1${RESET}"
}
function warn {
	echo -e "${YELLOW}$1${RESET}"
}

#
################################


TMP_DIR="/tmp"
OPT_DIR="/opt"

# NOTE: working fine on x64 with Ubuntu 20.04 LTS
# NOTE: working fine on arm64 with Ubuntu 20.04 LTS (update: 2021.11.25.)
# NOTE: working fine on Raspberry Pi 4 (arm64) with Raspberry Pi OS Bullseye (updated: 2021.11.25.)
function install_linux {
	if [ -z $TERMUX_VERSION ]; then
		warn ">>> installing essential packages..."

		if [ -x /usr/bin/apt-get ]; then
			sudo apt-get install -y build-essential curl libffi-dev libffi7 libgmp-dev libgmp10 libncurses-dev libncurses5 libtinfo5 llvm libnuma-dev stylish-haskell
		else
			error "* distro not supported"
		fi

		warn ">>> installing ghcup..."
		curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
	else  # termux
		error "* termux not supported yet."
	fi
}

function install_macos {
	warn ">>> installing ghcup..."
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

	warn ">>> installing stylish-haskell..."
	LATEST_ZIP=`curl -s "https://api.github.com/repos/haskell/stylish-haskell/releases" | grep "https" | grep "darwin" | grep "$PLATFORM" | cut -d \" -f4 | head -n 1`
	GHCUP_BIN_DIR="$HOME/.ghcup/bin"
	STYLISH_HASKELL_BIN="$GHCUP_BIN_DIR/stylish-haskell"
	DOWNLOADED_ZIP="$GHCUP_BIN_DIR/stylish-haskell.zip"
	wget -O $DOWNLOADED_ZIP $LATEST_ZIP && \
		cd $GHCUP_BIN_DIR && \
		unzip -j "stylish-haskell.zip" "*/stylish-haskell" && \
		chmod +x $STYLISH_HASKELL_BIN && \
		rm $DOWNLOADED_ZIP
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

