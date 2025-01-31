#!/usr/bin/env bash

# bin/install_asdf.sh
#
# Install asdf
#
# created on : 2022.04.14.
# last update: 2025.01.31.

################################
#
# frequently updated values

# https://github.com/asdf-vm/asdf/releases
VERSION="0.16.0"

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

function install_macos {
	brew install asdf
}

function install_termux {
	error "* termux is not supported yet"
}

function install_linux {
	case "$(uname -m)" in
	aarch64) ARCH="arm64" ;;
	*) ARCH="amd64" ;;
	esac
	rm -rf ~/.asdf &&
		mkdir -p ~/.asdf/bin/ &&
		wget -qO- "https://github.com/asdf-vm/asdf/releases/download/v$VERSION/asdf-v$VERSION-linux-$ARCH.tar.gz" | gunzip | tar xf - -C ~/.asdf/bin/ &&
		info "> installed $(~/.asdf/bin/asdf --version)"
}

case "$OSTYPE" in
darwin*) install_macos ;;
linux-android) install_termux ;;
linux*) install_linux ;;
*) error "* not supported yet: $OSTYPE" ;;
esac
