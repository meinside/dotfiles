#!/usr/bin/env bash

# bin/install_pico_sdk.sh
#
# Install SDK for Raspberry Pi Pico development.
#
# https://datasheets.raspberrypi.org/pico/getting-started-with-pico.pdf
#
# created on: 2021.08.24.
# updated on: 2026.04.17.

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

readonly PICO_DIR="$HOME/srcs/pico"
readonly PICO_SDK_DIRNAME="pico-sdk"
readonly PICO_SDK_DIR="$PICO_DIR/$PICO_SDK_DIRNAME"
readonly PICO_EXAMPLES_DIRNAME="pico-examples"
readonly PICO_EXAMPLES_DIR="$PICO_DIR/$PICO_EXAMPLES_DIRNAME"

function pull_repositories {
	warn ">>> pulling repositories..."
	mkdir -p "$PICO_DIR"
	cd "$PICO_DIR"

	if [ -d "$PICO_SDK_DIR" ]; then
		warn ">>> $PICO_SDK_DIR already exists, skipping clone of pico-sdk."
	else
		git clone -b master https://github.com/raspberrypi/pico-sdk.git "$PICO_SDK_DIRNAME"
		cd "$PICO_SDK_DIR"
		git submodule update --init
		cd "$PICO_DIR"
	fi

	if [ -d "$PICO_EXAMPLES_DIR" ]; then
		warn ">>> $PICO_EXAMPLES_DIR already exists, skipping clone of pico-examples."
	else
		git clone -b master https://github.com/raspberrypi/pico-examples.git "$PICO_EXAMPLES_DIRNAME"
	fi
}

function show_guides {
	warn ">>> $ export PICO_SDK_PATH=$PICO_SDK_DIR"
	info ">>> get cmake ready: $ cd $PICO_EXAMPLES_DIR && mkdir build && cd build && cmake .."
	info ">>> then build any example: $ cd $PICO_EXAMPLES_DIR/build/blink && cmake --build ."
}

function install_macos_packages {
	warn ">>> installing packages..." &&
		brew tap ArmMbed/homebrew-formulae &&
		brew install cmake arm-none-eabi-gcc
}

function install_macos {
	install_macos_packages &&
		pull_repositories &&
		show_guides
}

function install_linux_packages {
	warn ">>> installing packages..."

	if [ -x /usr/bin/apt-get ]; then
		sudo apt-get -y install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi build-essential libstdc++-arm-none-eabi-newlib
	else
		error "* distro not supported"
		return 1
	fi
}

function install_linux {
	install_linux_packages &&
		pull_repositories &&
		show_guides
}

function install_termux {
	error "* termux not supported yet."
	return 1
}

case "$OSTYPE" in
darwin*) install_macos ;;
linux-android) install_termux ;;
linux*) install_linux ;;
*) error "* not supported yet: $OSTYPE" ;;
esac
