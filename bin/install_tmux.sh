#!/usr/bin/env bash

# bin/install_tmux.sh
#
# Build and install the latest version of tmux.
#
# created on : 2023.08.03.
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

# https://github.com/tmux/tmux/releases
readonly TMUX_VERSION="3.5a" # NOTE: target version
readonly TMUX_SRC_FILENAME="tmux-${TMUX_VERSION}.tar.gz"
readonly TMUX_SRC_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/${TMUX_SRC_FILENAME}"
readonly TMP_DIR="/tmp"
readonly TMUX_SRC_DIR="$TMP_DIR/tmux-${TMUX_VERSION}"
readonly TMUX_SRC_TARBALL="$TMP_DIR/${TMUX_SRC_FILENAME}"

# cleanup tarball and extracted directory (on success or failure)
function cleanup_tmux_build {
	if [ -f "$TMUX_SRC_TARBALL" ] || [ -d "$TMUX_SRC_DIR" ]; then
		rm -f "$TMUX_SRC_TARBALL"
		rm -rf "$TMUX_SRC_DIR"
		info ">>> removed temporary directory and files."
	fi
}

# for macOS
function install_macos {
	brew install tmux
}

# for linux
function install_linux {
	if [ -x /usr/bin/apt-get ]; then
		trap cleanup_tmux_build EXIT

		# remove stale artifacts if present
		cleanup_tmux_build

		sudo apt-get -y purge tmux

		info ">>> installing essential packages..."
		sudo apt-get -y install libevent-dev ncurses-dev build-essential bison pkg-config
		info ">>> downloading: $TMUX_SRC_URL"
		cd "$TMP_DIR"
		wget "$TMUX_SRC_URL"
		tar xzf "$TMUX_SRC_FILENAME"
		info ">>> building..."
		cd "$TMUX_SRC_DIR"
		./configure
		make
		sudo make install
		info ">>> installed tmux-${TMUX_VERSION}!"
	else
		error "* distro not supported"
		return 1
	fi
}

# for termux
function install_termux {
	pkg install tmux
}

case "$OSTYPE" in
darwin*) install_macos ;;
linux-android) install_termux ;;
linux*) install_linux ;;
*) error "* not supported yet: $OSTYPE" ;;
esac
