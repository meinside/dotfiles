#!/usr/bin/env bash

# install_racket.sh
#
# Build and install Racket from the official repository.
#
# created on : 2021.11.24.
# last update: 2021.12.03.
#
# by meinside@gmail.com

source ./common.sh

TEMP_DIR="/tmp"
INSTALLATION_DIR="/opt"

REPOSITORY="https://github.com/racket/racket.git"

# XXX - edit for different version
VERSION="8.3"

# install essential packages
function prep {
    warn ">>> installing essential packages..."

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
    warn ">>> cloning repository...(version: $VERSION)"

    SRC_DIR="$TEMP_DIR/racket-$VERSION"

    sudo rm -rf "$SRC_DIR" && \
	git clone -b "v$VERSION" "$REPOSITORY" "$SRC_DIR"
}

# build and install binaries
function build_and_install {
    warn ">>> building racket..."

    RACKET_DIR="${INSTALLATION_DIR}/racket-${VERSION}"

    cd "$SRC_DIR/" && \
	sudo make -j$(nproc) unix-style PREFIX="$RACKET_DIR" && \
	sudo chown -R "$USER" "$RACKET_DIR" && \
	sudo ln -sfn "$RACKET_DIR" "$INSTALLATION_DIR/racket"
}

# install
function install {
    clone_repo && build_and_install && \
	info ">>> racket ${VERSION} was installed at: $RACKET_DIR"
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
    *) error "* not supported yet: $OSTYPE" ;;
esac

