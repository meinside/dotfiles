#!/usr/bin/env bash

# install_babashka.sh
#
# Install babashka
# (https://github.com/babashka/babashka#installation)
#
# created on : 2021.03.31.
# last update: 2021.12.03.
#
# by meinside@gmail.com


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


INSTALLATION_DIR="/opt"

function install_macos {
	brew install borkdude/brew/babashka
}

function install_linux {
	if [ -z $TERMUX_VERSION ]; then
		BB_DIR="${INSTALLATION_DIR}/babashka"

		sudo rm -rf $BB_DIR && \
			sudo mkdir -p $BB_DIR && \
			curl https://raw.githubusercontent.com/babashka/babashka/master/install -sSf | \
			sudo bash -s -- --dir $BB_DIR
	else  # termux
		error "* termux not supported yet."
	fi
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

