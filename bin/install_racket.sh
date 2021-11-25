#!/usr/bin/env bash

# install_racket.sh
#
# Build and install Racket from the official repository.
#
# created on : 2021.11.24.
# last update: 2021.11.25.
#
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

TEMP_DIR="/tmp"
INSTALLATION_DIR="/opt"

REPOSITORY="https://github.com/racket/racket.git"

# XXX - edit for different version
VERSION="8.3"

# install essential packages
function prep {
	echo -e "${YELLOW}>>> Installing essential packages...${RESET}"

	if [[ $(apt-cache search --names-only 'libjpeg62-turbo-dev') ]]; then
		sudo apt-get install -y -m git gcc libc6-dev libcairo2-dev libpango1.0-dev libjpeg62-turbo-dev
	elif [[ $(apt-cache search --names-only 'libjpeg62-dev') ]]; then
		sudo apt-get install -y -m git gcc libc6-dev libcairo2-dev libpango1.0-dev libjpeg62-dev
	else
		sudo apt-get install -y -m git gcc libc6-dev libcairo2-dev libpango1.0-dev
	fi
}

# clone the repository with the specified version
function clone_repo {
	echo -e "${YELLOW}>>> Cloning repository...(version: $VERSION)${RESET}"

	SRC_DIR="$TEMP_DIR/racket-$VERSION"

	sudo rm -rf "$SRC_DIR" && \
		git clone -b "v$VERSION" "$REPOSITORY" "$SRC_DIR"
}

# build and install binaries
function build_and_install {
	echo -e "${YELLOW}>>> Building Racket...${RESET}"

	RACKET_DIR="${INSTALLATION_DIR}/racket-${VERSION}"

	cd "$SRC_DIR/" && \
		sudo make -j$(nproc) unix-style PREFIX="$RACKET_DIR" && \
		sudo chown -R "$USER" "$RACKET_DIR" && \
		sudo ln -sfn "$RACKET_DIR" "$INSTALLATION_DIR/racket"
}

# install
function install {
	clone_repo && build_and_install && \
		echo -e "${GREEN}>>> Racket ${VERSION} was installed at: $RACKET_DIR${RESET}"
}

# for macOS
function install_macos {
	brew install minimal-racket
}

# for linux
function install_linux {
	prep && install
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

