#!/usr/bin/env bash

# bin/install_ffmpeg.sh
# 
# for building ffmpeg from source code
#
# (pass '--do-not-clean' argument for preserving files after install)
# 
# last update: 2024.05.30.


################################
#
# frequently updated values

# https://github.com/FFmpeg/FFmpeg/tags
FFMPEG_VERSION="n7.0.1" # XXX - edit for newer ffmpeg version


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


TMP_DIR=/tmp/ffmpeg

function prep {
	# install needed packages
	if [ -x /usr/bin/apt-get ]; then
		sudo apt-get install -y build-essential \
			libx264-dev \
			libx265-dev libnuma-dev \
			libvpx-dev \
			libfdk-aac-dev \
			libmp3lame-dev \
			libvorbis-dev \
			libopus-dev \
			libdav1d-dev
	else
		error "* distro not supported"
	fi

	clean
}

function clean {
	rm -rf $TMP_DIR
}

function install {
	PLATFORM=$(uname -m)
	case "$PLATFORM" in
		arm64) ARCH="aarch64" ;;
		arm*) ARCH="armel" ;;
		*) ARCH=$PLATFORM ;;
	esac

	# clone source code, configure, make, and install
	git clone --depth=1 -b $FFMPEG_VERSION https://github.com/FFmpeg/FFmpeg.git $TMP_DIR && \
		cd $TMP_DIR && \
		./configure --arch="$ARCH" --target-os=linux --enable-gpl --enable-nonfree \
			--enable-libx264 \
			--enable-libx265 \
			--enable-libvpx \
			--enable-libfdk-aac \
			--enable-libmp3lame \
			--enable-libvorbis \
			--enable-libopus \
			--enable-libdav1d && \
		make -j$(nproc) && \
		sudo make install
}

function install_linux {
	if [ -z "$TERMUX_VERSION" ]; then
		prep && install

		# check if '--do-not-clean' argument was given
		if [[ $1 != '--do-not-clean' ]]; then
			clean
		else
			warn ">>> ffmpeg files remain in $TMP_DIR"
		fi
	else  # termux
		error "* termux not supported yet."
	fi
}

function install_macos {
	brew install ffmpeg
}

case "$OSTYPE" in
	darwin*) install_macos "$@" ;;
	linux*) install_linux "$@" ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

