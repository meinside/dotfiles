#!/usr/bin/env bash

# install_babashka.sh
#
# Install babashka
# (https://github.com/babashka/babashka#installation)
#
# created on : 2021.03.31.
# last update: 2021.03.31.
#
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

INSTALLATION_DIR="/opt"

PLATFORM=`uname -m`     # armv7l, armv6l, ...

function install_macos {
	brew install borkdude/brew/babashka
}

function install_linux {

	BB_DIR="${INSTALLATION_DIR}/babashka"

	sudo rm -rf $BB_DIR && \
		sudo mkdir -p $BB_DIR && \
		curl https://raw.githubusercontent.com/babashka/babashka/master/install -sSf | \
		sudo bash -s -- --dir $BB_DIR

}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

