#!/usr/bin/env bash

# install_nvim.sh
# 
# for building neovim from source code
#
# last update: 2021.05.27.
# 
# by meinside@gmail.com

# * To install nightly version:
#
# $ ./install_nvim.sh --nightly
#
# * Update alternatives with:
#
# $ sudo update-alternatives --install /usr/bin/vi vi /usr/local/bin/nvim 60
# $ sudo update-alternatives --config vi
# $ sudo update-alternatives --install /usr/bin/vim vim /usr/local/bin/nvim 60
# $ sudo update-alternatives --config vim
# $ sudo update-alternatives --install /usr/bin/editor editor /usr/local/bin/nvim 60
# $ sudo update-alternatives --config editor

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

TMP_DIR=/tmp/nvim

# https://github.com/neovim/neovim/releases
NVIM_VERSION="v0.4.4"

function prep {
	# install needed packages
	sudo apt-get install -y ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip

	# clean tmp directory
	clean
}

function clean {
	sudo rm -rf $TMP_DIR
}

# $1: nightly or not
function install {
	tag=$NVIM_VERSION

	if [[ $1 == "--nightly" ]]; then
		tag="nightly"
	fi

	echo -e "${YELLOW}>>> Will install Neovim version ${tag}...${RESET}"

	git clone https://github.com/neovim/neovim.git $TMP_DIR && \
		cd $TMP_DIR && \
		git checkout ${tag}

	# configure and build
	rm -rf build && \
		make clean && \
		make CMAKE_BUILD_TYPE=RelWithDebInfo

	# install
	sudo make install
}

# install for macOS
function install_macos {
	if [[ $1 == "--nightly" ]]; then
		brew install —-HEAD neovim
	else
		brew install neovim
	fi
}

# install for linux
#
# $1: nightly or not
function install_linux {
	prep && install $1 && clean
}

case "$OSTYPE" in
	darwin*) install_macos $1 ;;
	linux*) install_linux $1 ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

