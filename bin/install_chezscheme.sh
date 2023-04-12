#!/usr/bin/env bash

# bin/install_chezscheme.sh
#
# for building & installing ChezScheme from source code
#
# last update: 2023.04.12.
#
# by meinside@duck.com


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


TMP_DIR=/tmp/ChezScheme

function clean {
    sudo rm -rf $TMP_DIR
}

# install
function install {
    warn ">>> installing ChezScheme..."

    # clone, configure, build, and install
    rm -rf $TMP_DIR && \
	git clone https://github.com/racket/ChezScheme.git $TMP_DIR && \
	cd $TMP_DIR && \
	./configure --disable-x11 && \
	make build && \
	sudo make install && \
	info ">>> ChezScheme installed"
}

# install for macOS
function install_macos {
    #brew install --build-from-source chezscheme
    error "* macOS not supported yet."
}

# install for linux
function install_linux {
    if [ -z "$TERMUX_VERSION" ]; then
	install && clean
    else  # termux
	error "* termux not supported yet."
    fi
}

case "$OSTYPE" in
    darwin*) install_macos ;;
    linux*) install_linux ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

