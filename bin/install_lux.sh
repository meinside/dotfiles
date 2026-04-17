#!/usr/bin/env bash

# bin/install_lux.sh
#
# Install lux-cli (Lua Package Manager)
# https://github.com/nvim-neorocks/lux
#
# created on : 2025.04.16.
# last update: 2026.04.17.

set -euo pipefail

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

function ensure_cargo {
	if ! command -v cargo >/dev/null 2>&1; then
		error "* cargo not found; install rust toolchain first (e.g. via rustup or asdf)"
		return 1
	fi
}

function install_macos {
	ensure_cargo

	# install dependencies
	brew install gpgme

	install_cargo_things
}

function install_linux {
	ensure_cargo

	# install dependencies
	if [ -x /usr/bin/apt-get ]; then
		sudo apt-get -y install \
			libgpg-error-dev \
			libgpgme-dev \
			libluajit-5.1-dev
	else
		error "* distro not supported"
		return 1
	fi

	install_cargo_things
}

# FIXME: TODO: when this project releases stable releases, download and use them
function install_cargo_things {
	cargo install lux-cli \
		--locked \
		--profile release \
		--features vendored
}

case "$OSTYPE" in
darwin*) install_macos ;;
linux-android)
	error "* termux not supported yet."
	exit 1
	;;
linux*) install_linux ;;
*) error "* not supported yet: $OSTYPE" ;;
esac
