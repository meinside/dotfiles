#!/usr/bin/env bash

# bin/install_ffmpeg.sh
#
# for building ffmpeg from source code.
#
# NOTE: on failure, build artifacts under $TMP_DIR are preserved for
# debugging (thanks to `set -e`); on success they are cleaned up.
#
# last update: 2026.04.17.

set -euo pipefail

# NOTE: see configure options at: https://github.com/FFmpeg/FFmpeg/blob/master/configure

################################
#
# frequently updated values

# https://github.com/FFmpeg/FFmpeg/tags
readonly FFMPEG_VERSION="n8.1" # XXX - edit for newer ffmpeg version

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
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${RED}$1${RESET}"
	else
		echo "$1"
	fi
}
function info {
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${GREEN}$1${RESET}"
	else
		echo "$1"
	fi
}
function warn {
	if [ -t 0 ] && [ -t 1 ]; then
		echo -e "${YELLOW}$1${RESET}"
	else
		echo "$1"
	fi
}

#
################################

readonly TMP_DIR=/tmp/ffmpeg

function prep {
	# install needed packages
	if [ -x /usr/bin/apt-get ]; then
		sudo apt-get install -y build-essential \
			libdav1d-dev \
			libfdk-aac-dev \
			libmp3lame-dev \
			libnuma-dev \
			libopus-dev \
			libvorbis-dev \
			libvpx-dev \
			libwebp-dev \
			libx264-dev \
			libx265-dev \
			libxvidcore-dev
	else
		error "* distro not supported"
		return 1
	fi

	clean
}

function clean {
	rm -rf "$TMP_DIR"
}

function install {
	local platform arch
	platform=$(uname -m)
	case "$platform" in
	arm64) arch="aarch64" ;;
	arm*) arch="armel" ;;
	*) arch="$platform" ;;
	esac

	# clone source code, configure, make, and install
	git clone --depth=1 -b "$FFMPEG_VERSION" https://github.com/FFmpeg/FFmpeg.git "$TMP_DIR"
	cd "$TMP_DIR"
	./configure --arch="$arch" --target-os=linux --enable-gpl --enable-nonfree \
		--enable-libdav1d \
		--enable-libfdk-aac \
		--enable-libmp3lame \
		--enable-libopus \
		--enable-libvorbis \
		--enable-libvpx \
		--enable-libwebp \
		--enable-libx264 \
		--enable-libx265 \
		--enable-libxvid
	make -j"$(nproc)"
	sudo make install
}

function install_linux {
	prep
	install
	clean
}

function install_termux {
	error "* termux not supported yet."
	return 1
}

function install_macos {
	brew install ffmpeg
}

case "$OSTYPE" in
darwin*) install_macos ;;
linux-android) install_termux ;;
linux*) install_linux ;;
*) error "* not supported yet: $OSTYPE" ;;
esac
