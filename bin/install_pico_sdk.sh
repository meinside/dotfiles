#!/usr/bin/env bash

# install_pico_sdk.sh
#
# Install SDK for Raspberry Pi Pico development.
#
# https://datasheets.raspberrypi.org/pico/getting-started-with-pico.pdf
#
# created on: 2021.08.24.
# updated on: 2021.12.03.
#
# by meinside@gmail.com

source ./common.sh

PICO_DIR="$HOME/srcs/pico"
PICO_SDK_DIRNAME="pico-sdk"
PICO_SDK_DIR="$PICO_DIR/$PICO_SDK_DIRNAME"
PICO_EXAMPLES_DIRNAME="pico-examples"
PICO_EXAMPLES_DIR="$PICO_DIR/$PICO_EXAMPLES_DIRNAME"

function pull_repositories {
    warn ">>> pulling repositories..." && \
	mkdir -p $PICO_DIR && \
	cd $PICO_DIR && \
	git clone -b master https://github.com/raspberrypi/pico-sdk.git $PICO_SDK_DIRNAME && \
	cd $PICO_SDK_DIRNAME && \
	git submodule update --init && \
	cd $PICO_DIR && \
	git clone -b master https://github.com/raspberrypi/pico-examples.git
}

function show_guides {
    error ">>> $ export PICO_SDK_PATH=$PICO_SDK_DIR" && \
	info ">>> get cmake ready: $ cd $PICO_EXAMPLES_DIR && mkdir build && cd build && cmake .." && \
	info ">>> then build any example: $ cd $PICO_EXAMPLES_DIR/build/blink && cmake --build ."
}

function install_macos_packages {
    warn ">>> installing packages..." && \
	brew tap ArmMbed/homebrew-formulae && \
	brew install cmake arm-none-eabi-gcc
}

function install_macos {
    install_macos_packages && \
	pull_repositories && \
	show_guides
}

function install_linux_packages {
    warn ">>> installing packages..." && \
	sudo apt-get -y install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi build-essential libstdc++-arm-none-eabi-newlib
}

function install_linux {
    if [ -z $TERMUX_VERSION ]; then
	install_linux_packages && \
	    pull_repositories && \
	    show_guides
    else  # termux
	error "* termux not supported yet."
    fi
}

case "$OSTYPE" in
    darwin*) install_macos ;;
    linux*) install_linux ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

