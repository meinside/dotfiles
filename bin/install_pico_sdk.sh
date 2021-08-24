#!/usr/bin/env bash

# install_pico_sdk.sh
#
# Install SDK for Raspberry Pi Pico development.
#
# https://datasheets.raspberrypi.org/pico/getting-started-with-pico.pdf
#
# created on: 2021.08.24.
# updated on: 2021.08.24.
#
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

PICO_DIR="$HOME/srcs/pico"
PICO_SDK_DIRNAME="pico-sdk"
PICO_SDK_DIR="$PICO_DIR/$PICO_SDK_DIRNAME"
PICO_EXAMPLES_DIRNAME="pico-examples"
PICO_EXAMPLES_DIR="$PICO_DIR/$PICO_EXAMPLES_DIRNAME"

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

function pull_repositories {
	echo -e "${YELLOW}>>> Pulling repositories...${RESET}" && \
		mkdir -p $PICO_DIR && \
		cd $PICO_DIR && \
		git clone -b master https://github.com/raspberrypi/pico-sdk.git $PICO_SDK_DIRNAME && \
		cd $PICO_SDK_DIRNAME && \
		git submodule update --init && \
		cd $PICO_DIR && \
		git clone -b master https://github.com/raspberrypi/pico-examples.git
}

function show_guides {
	echo -e "${RED}>>> $ export PICO_SDK_PATH=$PICO_SDK_DIR${RESET}" && \
		echo -e "${GREEN}>>> Get cmake ready: $ cd $PICO_EXAMPLES_DIR && mkdir build && cd build && cmake ..${RESET}" && \
		echo -e "${GREEN}>>> Then build any example: $ cd $PICO_EXAMPLES_DIR/build/blink && make -j4${RESET}"
}

function install_macos_packages {
	echo -e "${YELLOW}>>> Installing packages...${RESET}" && \
		brew tap ArmMbed/homebrew-formulae && \
		brew install cmake arm-none-eabi-gcc
}

function install_macos {
	install_macos_packages && \
		pull_repositories && \
		show_guides
}

function install_linux_packages {
	echo -e "${YELLOW}>>> Installing packages...${RESET}" && \
		sudo apt-get -y install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi build-essential libstdc++-arm-none-eabi-newlib
}

function install_linux {
	install_linux_packages && \
		pull_repositories && \
		show_guides
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

