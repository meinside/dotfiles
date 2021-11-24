#!/usr/bin/env bash

# install_racket.sh
#
# Build and install Racket from the official repository.
#
# created on : 2021.11.24.
# last update: 2021.11.24.
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

function prep {
	# install essential packages
	echo -e "${YELLOW}>>> Installing essential packages...${RESET}"

	sudo apt-get install -y git gcc libc6-dev
}

function clone_repo {
	echo -e "${YELLOW}>>> Cloning repository...(version: $VERSION)${RESET}"

	SRC_DIR="$TEMP_DIR/racket-$VERSION"

	# clone the repository
	rm -rf "$SRC_DIR" && \
		git clone -b "v$VERSION" "$REPOSITORY" "$SRC_DIR"
}

function build_and_install {
	echo -e "${YELLOW}>>> Building Racket...${RESET}"

	RACKET_DIR="${INSTALLATION_DIR}/racket-${VERSION}"

	# build
	cd "$SRC_DIR/" && \
		make -j2 && \
		sudo make unix-style PREFIX="$RACKET_DIR" && \
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

