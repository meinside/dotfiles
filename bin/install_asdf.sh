#!/usr/bin/env bash

# bin/install_asdf.sh
#
# Install asdf
#
# created on : 2022.04.14.
# last update: 2024.04.24.


################################
#
# frequently updated values

# https://github.com/asdf-vm/asdf/releases
VERSION="0.13.1"


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
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${RED}$1${RESET}"
	else
		echo "$1"
	fi
}
function info {
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${GREEN}$1${RESET}"
	else
		echo "$1"
	fi
}
function warn {
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${YELLOW}$1${RESET}"
	else
		echo "$1"
	fi
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

function install_termux {
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

