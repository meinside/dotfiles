#!/usr/bin/env bash

# bin/install_tmux.sh
#
# Build and install the latest version of tmux.
#
# created on : 2023.08.03.
# last update: 2024.10.14.


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


# https://github.com/tmux/tmux/releases
TMUX_VERSION="3.5a" # NOTE: target version
TMUX_SRC_FILENAME="tmux-${TMUX_VERSION}.tar.gz"
TMUX_SRC_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/${TMUX_SRC_FILENAME}"
TMP_DIR="/tmp"

# for macOS
function install_macos {
	brew install tmux
}

# for linux
function install_linux {
	if [ -z "$TERMUX_VERSION" ]; then
		if [ -x /usr/bin/apt-get ]; then
			sudo apt-get -y purge tmux

			info ">>> installing essential packages..." && \
				sudo apt-get -y install libevent-dev ncurses-dev build-essential bison pkg-config && \
				info ">>> downloading: $TMUX_SRC_URL" && \
				cd $TMP_DIR && \
				wget $TMUX_SRC_URL && \
				tar xzf "${TMUX_SRC_FILENAME}"
				info ">>> building..." && \
				cd "tmux-${TMUX_VERSION}" && \
				./configure && \
				make && \
				sudo make install && \
				info ">>> installed tmux-${TMUX_VERSION}!"
		else
			error "* distro not supported"
		fi

		cd $TMP_DIR && \
			rm -f "${TMUX_SRC_FILENAME}"
			rm -rf "tmux-${TMUX_VERSION}" && \
			error ">>> removed temporary directory and files."
	else  # termux
		pkg install tmux
	fi
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac
