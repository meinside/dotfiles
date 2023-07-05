#!/usr/bin/env bash

# bin/install_asdf.sh
#
# Install asdf
#
# created on : 2022.04.14.
# last update: 2023.07.05.
#
# by meinside@meinside.dev


################################
#
# frequently updated values

# https://github.com/asdf-vm/asdf/releases
VERSION="0.12.0"


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

function checkout {
	rm -rf ~/.asdf && \
		git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v$VERSION
}

function install_macos {
	checkout
}

function install_termmux {
	error "* termux is not supported yet"
}

function install_linux {
	checkout
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux-android) install_termux ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

