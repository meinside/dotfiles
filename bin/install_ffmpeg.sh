#!/usr/bin/env bash

# bin/install_ffmpeg.sh
#
# for building ffmpeg from source code.
#
# last update: 2026.08.06.

set -euo pipefail

# NOTE: see configure options at: https://github.com/FFmpeg/FFmpeg/blob/master/configure

################################
#
# frequently updated values

# https://github.com/FFmpeg/FFmpeg/tags
readonly FFMPEG_VERSION="n9.0" # XXX - edit for newer ffmpeg version

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

# base directory for the build; override with TMPDIR=... (defaults to /tmp)
readonly TMP_DIR="${TMPDIR:-/tmp}/ffmpeg"

function prep {
	# install needed packages
	if [ -x /usr/bin/apt-get ]; then
		sudo apt-get update
		sudo apt-get install -y build-essential \
			git \
			nasm \
			pkg-config \
			libaom-dev \
			libass-dev \
			libdav1d-dev \
			libfdk-aac-dev \
			libfontconfig-dev \
			libfreetype-dev \
			libfribidi-dev \
			libharfbuzz-dev \
			libmp3lame-dev \
			libnuma-dev \
			libopenh264-dev \
			libopus-dev \
			libssl-dev \
			libsvtav1enc-dev \
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
	# clone source code, configure, make, and install
	#
	# NOTE: --arch is intentionally omitted; configure detects it from the host.
	git clone --depth=1 -b "$FFMPEG_VERSION" https://github.com/FFmpeg/FFmpeg.git "$TMP_DIR"
	cd "$TMP_DIR"
	./configure --target-os=linux --enable-gpl --enable-nonfree \
		--enable-openssl \
		--enable-libaom \
		--enable-libass \
		--enable-libdav1d \
		--enable-libfdk-aac \
		--enable-libfontconfig \
		--enable-libfreetype \
		--enable-libfribidi \
		--enable-libharfbuzz \
		--enable-libmp3lame \
		--enable-libopenh264 \
		--enable-libopus \
		--enable-libsvtav1 \
		--enable-libvorbis \
		--enable-libvpx \
		--enable-libwebp \
		--enable-libx264 \
		--enable-libx265 \
		--enable-libxvid
	make -j"$(nproc)"
	sudo make install
	sudo ldconfig

	# smoke test the freshly installed binary
	info "* installed: $(ffmpeg -version | head -1)"
}

function install_linux {
	# cleanup tmp directory on exit (success or failure)
	trap clean EXIT

	prep
	install
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
