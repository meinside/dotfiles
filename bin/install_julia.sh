#!/usr/bin/env bash

# install_julia.sh
#
# install pre-built Julia (https://julialang.org/downloads/)
#
# created on : 2021.12.01.
# last update: 2021.12.01.
#
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# XXX - edit these for other versions
VERSION="1.7.0"
VERSION_SHORT="1.7"

PLATFORM=`uname -m`	# armv7l, armv6l, ...
PLATFORM_SHORT="$PLATFORM"

# x86_64 = x64
case "$PLATFORM" in
	x86_64) PLATFORM_SHORT="x64" ;;
esac

# https://julialang-s3.julialang.org/bin/linux/aarch64/1.7/julia-1.7.0-linux-aarch64.tar.gz
JULIA_DIST_BASEURL="https://julialang-s3.julialang.org/bin/linux"
TEMP_DIR="/tmp"
FILENAME="julia-${VERSION}-linux-${PLATFORM}.tar.gz"
DOWNLOAD_PATH="${JULIA_DIST_BASEURL}/${PLATFORM_SHORT}/${VERSION_SHORT}/$FILENAME"
INSTALLATION_DIR="/opt"
JULIA_DIR="$INSTALLATION_DIR/julia-${VERSION}"

function install_linux {
	if [ -n $TERMUX_VERSION ]; then
		TEMP_DIR="$PREFIX/tmp"
	fi

	echo -e "${YELLOW}>>> downloading version $VERSION ...${RESET}" && \
		wget "$DOWNLOAD_PATH" -P "$TEMP_DIR" && \
		echo -e "${YELLOW}>>> extracting to: $JULIA_DIR ...${RESET}" && \
		sudo mkdir -p "$INSTALLATION_DIR" && \
		sudo tar -xzvf "$TEMP_DIR/$FILENAME" -C "$INSTALLATION_DIR" && \
		sudo chown -R $USER "$JULIA_DIR" && \
		sudo ln -sfn "$JULIA_DIR" "$INSTALLATION_DIR/julia" && \
		echo -e "${GREEN}>>> julia v$VERSION was installed at: $JULIA_DIR ${RESET}"
}

function install_macos {
	brew install julia
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac
