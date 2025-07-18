#!/usr/bin/env bash

# bin/install_asdf.sh
#
# Install lux-cli (Lua Package Manager)
# https://github.com/nvim-neorocks/lux
#
# created on : 2025.04.16.
# last update: 2025.07.18.

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
	# install dependencies
	brew install gpgme

	install_cargo_things
}

function install_linux {
	# install dependencies
	sudo apt install -y libgpg-error-dev libgpgme-dev libluajit-5.1-dev

	install_cargo_things
}

# FIXME: TODO: when this project releases stable releases, download and use them
function install_cargo_things {
	## install rust toolchain
	#cargo install cargo-binstall
	#
	## install lux
	#cargo binstall lux-cli --locked

	cargo install lux-cli --locked
}

case "$OSTYPE" in
darwin*) install_macos ;;
linux*) install_linux ;;
*) error "* not supported yet: $OSTYPE" ;;
esac
