#!/usr/bin/env bash

# bin/install_mosh.sh
#
# Manually build mosh from `master` branch. (1.3.2 doesn't support 24-bit colors yet)
#
# created on : 2021.08.11.
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

readonly MOSH_REPO="https://github.com/mobile-shell/mosh"
readonly TMP_DIR="/tmp"
readonly BUILD_DIR="$TMP_DIR/mosh"

# cleanup build directory on exit (success or failure)
function cleanup_build_dir {
	if [ -d "$BUILD_DIR" ]; then
		rm -rf "$BUILD_DIR" &&
			info ">>> removed temporary directory."
	fi
}

# for macOS
function install_macos {
	brew uninstall mosh
	brew install --HEAD mosh
}

# for linux
function install_linux {
	if [ -x /usr/bin/apt-get ]; then
		trap cleanup_build_dir EXIT

		# remove stale build directory if present
		cleanup_build_dir

		sudo apt-get -y purge mosh

		info ">>> installing essential packages..."
		sudo apt-get -y install build-essential pkg-config autoconf protobuf-compiler libncurses5-dev zlib1g-dev libssl-dev libprotobuf-dev
		info ">>> cloning: $MOSH_REPO"
		cd "$TMP_DIR"
		git clone "$MOSH_REPO"
		info ">>> building..."
		cd "$BUILD_DIR"
		./autogen.sh
		./configure
		make
		sudo make install
		info ">>> installed mosh from the master branch!"
	else
		error "* distro not supported"
		return 1
	fi
}

# for termux
function install_termux {
	# NOTE: termux's latest mosh doesn't support 24-bit colors yet.
	pkg install mosh
}

case "$OSTYPE" in
darwin*) install_macos ;;
linux-android) install_termux ;;
linux*) install_linux ;;
*) error "* not supported yet: $OSTYPE" ;;
esac
