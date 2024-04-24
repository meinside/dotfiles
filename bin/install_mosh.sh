#!/usr/bin/env bash

# bin/install_mosh.sh
#
# Manually build mosh from `master` branch. (1.3.2 doesn't support 24-bit colors yet)
#
# created on : 2021.08.11.
# last update: 2024.04.24.


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


MOSH_REPO="https://github.com/mobile-shell/mosh"
TMP_DIR="/tmp"

# for macOS
function install_macos {
	brew uninstall mosh
	brew install --HEAD mosh
}

# for linux
function install_linux {
	if [ -z "$TERMUX_VERSION" ]; then

		if [ -x /usr/bin/apt-get ]; then
			sudo apt-get -y purge mosh

			info ">>> installing essential packages..." && \
				sudo apt-get -y install build-essential pkg-config autoconf protobuf-compiler libncurses5-dev zlib1g-dev libssl-dev libprotobuf-dev && \
				info ">>> cloning: $MOSH_REPO" && \
				cd $TMP_DIR && \
				git clone $MOSH_REPO && \
				info ">>> building..." && \
				cd mosh && \
				./autogen.sh && \
				./configure && \
				make && \
				sudo make install && \
				info ">>> installed mosh from the master branch!"
		else
			error "* distro not supported"
		fi

		cd $TMP_DIR && \
			rm -rf mosh && \
			error ">>> removed temporary directory."
	else  # termux
		# NOTE: termux's latest mosh doesn't support 24-bit colors yet.
		pkg install mosh
	fi
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac
