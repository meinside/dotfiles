#!/usr/bin/env bash

# install_ffmpeg.sh
# 
# for building ffmpeg from source code
#
# (pass '--do-not-clean' argument for preserving files after install)
# 
# last update: 2021.12.03.
# 
# by meinside@gmail.com


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


# https://github.com/FFmpeg/FFmpeg/tags
FFMPEG_VERSION="n4.3" # XXX - update this

TMP_DIR=/tmp/ffmpeg

function prep {
	# install needed packages
	sudo apt-get install -y build-essential \
		libx264-dev \
		libx265-dev libnuma-dev \
		libvpx-dev \
		libmp3lame-dev \
		libvorbis-dev \
		libopus-dev

	clean
}

function clean {
	rm -rf $TMP_DIR
}

function install {
	git clone --depth=1 -b $FFMPEG_VERSION https://github.com/FFmpeg/FFmpeg.git $TMP_DIR
	cd $TMP_DIR

	PLATFORM=`uname -m`
	case "$PLATFORM" in
		arm64) ARCH="aarch64" ;;
		arm*) ARCH="armel" ;;
		*) ARCH=$PLATFORM ;;
	esac

	./configure --arch=$ARCH --target-os=linux --enable-gpl --enable-nonfree \
		--enable-libx264 \
		--enable-libx265 \
		--enable-libvpx \
		--enable-libmp3lame \
		--enable-libvorbis \
		--enable-libopus
	make -j$(nproc)

	# install
	sudo make install
}

function install_linux {
	if [ -z $TERMUX_VERSION ]; then
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
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

