#!/usr/bin/env bash

# install_vale.sh
#
# Download and install latest version of vale from github release page.
#
# created on : 2022.07.29.
# last update: 2022.07.29.
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


VALE_DIR="$HOME/srcs/go/bin"
VALE_BIN="$VALE_DIR/vale"

# install
function install {
	os=$(uname -s)
	case $os in
		Darwin)
			target="macOS"
			;;
		Linux)
			target="Linux"
			;;
		*) error "* not supported: $os" ;;
	esac

	machine=$(uname -m)
	case $machine in
		aarch64|arm64)
			# ARM
			target="${target}_arm64"
			;;
		x86_64)
			# Intel
			target="${target}_64-bit"
			;;
		*) error "* not supported yet: $machine" ;;
	esac

	LATEST_TGZ=`curl -s "https://api.github.com/repos/errata-ai/vale/releases" | grep "https" | grep "$target"| cut -d \" -f4 | head -n 1`

	wget -qO- $LATEST_TGZ | tar xz -C $VALE_DIR vale

	if [ -x $VALE_BIN ]; then
		info ">>> successfully installed vale at: ${VALE_BIN}"

		$VALE_BIN sync
	fi
}

case "$OSTYPE" in
	darwin*|linux*) install ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

