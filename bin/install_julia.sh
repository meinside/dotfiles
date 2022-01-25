#!/usr/bin/env bash

# install_julia.sh
#
# install pre-built Julia (https://julialang.org/downloads/)
#
# created on : 2021.12.01.
# last update: 2022.01.25.
#
# by meinside@gmail.com


################################
#
# frequently updated values

# XXX - edit these for other versions
VERSION="1.7.1"
VERSION_SHORT="1.7"


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
PLATFORM_SHORT="$PLATFORM"

# x86_64 = x64
case "$PLATFORM" in
	x86_64) PLATFORM_SHORT="x64" ;;
esac

JULIA_DIST_BASEURL="https://julialang-s3.julialang.org/bin/linux"
FILENAME="julia-${VERSION}-linux-${PLATFORM}.tar.gz"
DOWNLOAD_PATH="${JULIA_DIST_BASEURL}/${PLATFORM_SHORT}/${VERSION_SHORT}/$FILENAME"

# NOTE: in termux, $PREFIX = '/data/data/com.termux/files/usr'
INSTALLATION_DIR="$PREFIX/opt"
TEMP_DIR="$PREFIX/tmp"
JULIA_DIR="$INSTALLATION_DIR/julia-${VERSION}"

function install_linux {
	if [ -z $TERMUX_VERSION ]; then
		warn ">>> downloading version $VERSION..." && \
			wget "$DOWNLOAD_PATH" -P "$TEMP_DIR" && \
			warn ">>> extracting to: $JULIA_DIR..." && \
			sudo mkdir -p "$INSTALLATION_DIR" && \
			sudo tar -xzvf "$TEMP_DIR/$FILENAME" -C "$INSTALLATION_DIR" && \
			sudo chown -R $USER "$JULIA_DIR" && \
			sudo ln -sfn "$JULIA_DIR" "$INSTALLATION_DIR/julia" && \
			info ">>> julia v$VERSION was installed at: $JULIA_DIR"
	else # termux
		error "* termux not supported yet."

		#warn ">>> downloading version $VERSION..." && \
		#	wget "$DOWNLOAD_PATH" -P "$TEMP_DIR" && \
		#	warn ">>> extracting to: $JULIA_DIR..." && \
		#	mkdir -p "$INSTALLATION_DIR" && \
		#	tar -xzvf "$TEMP_DIR/$FILENAME" -C "$INSTALLATION_DIR" && \
		#	ln -sfn "$JULIA_DIR" "$INSTALLATION_DIR/julia" && \
		#	info ">>> julia v$VERSION was installed at: $JULIA_DIR"
	fi
}

function install_macos {
	brew install julia
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac
