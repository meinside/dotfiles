#!/usr/bin/env bash

# install_mosh.sh
#
# Install mosh from master branch. (1.3.2 doesn't support 24-bit colors yet)
#
# created on : 2021.08.11.
# last update: 2021.12.03.


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


MOSH_REPO="https://github.com/mobile-shell/mosh"
TMP_DIR="/tmp"

# for macOS
function install_macos {
	brew uninstall mosh
	brew install --HEAD mosh
}

# for linux
function install_linux {
	if [ -z $TERMUX_VERSION ]; then
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

		cd $TMP_DIR && \
			rm -rf mosh && \
			error ">>> removed temporary directory."
	else  # termux
		pkg install termux
	fi
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac
