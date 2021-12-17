#!/usr/bin/env bash

# install_nodejs.sh
#
# install pre-built Node.js (LTS) for Linux from: https://nodejs.org/dist
#
# created on : 2013.07.19.
# last update: 2021.12.17.
#
# by meinside@gmail.com


################################
#
# frequently updated values

VERSION="16.13.1"	# XXX - edit this for other versions


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


PLATFORM=`uname -m`	# armv7l, armv6l, ...

# x86_64 = x64, aarch64 = arm64
case "$PLATFORM" in
    x86_64) PLATFORM="x64" ;;
    aarch64) PLATFORM="arm64" ;;
esac

NODEJS_DIST_BASEURL="https://nodejs.org/dist"
TEMP_DIR="/tmp"
FILENAME="node-v${VERSION}-linux-${PLATFORM}.tar.gz"
DOWNLOAD_PATH="$NODEJS_DIST_BASEURL/v$VERSION/$FILENAME"
INSTALLATION_DIR="/opt"
NODEJS_DIR="$INSTALLATION_DIR/`basename $FILENAME .tar.gz`"

function install_linux {
    if [ -z $TERMUX_VERSION ]; then
	warn ">>> downloading version $VERSION ..." && \
	    wget "$DOWNLOAD_PATH" -P "$TEMP_DIR" && \
	    warn ">>> extracting to: $NODEJS_DIR ..." && \
	    sudo mkdir -p "$INSTALLATION_DIR" && \
	    sudo tar -xzvf "$TEMP_DIR/$FILENAME" -C "$INSTALLATION_DIR" && \
	    sudo chown -R $USER "$NODEJS_DIR" && \
	    sudo ln -sfn "$NODEJS_DIR" "$INSTALLATION_DIR/node" && \
	    info ">>> nodejs v$VERSION was installed at: $NODEJS_DIR"
    else  # termux
	pkg install nodejs
    fi
}

function install_macos {
    brew install node
}

case "$OSTYPE" in
    darwin*) install_macos ;;
    linux*) install_linux ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

