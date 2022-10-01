#!/usr/bin/env bash

# bin/install_neovim.sh
# 
# for building neovim from source code
#
# last update: 2022.10.01.
# 
# by meinside@duck.com

# * To install nightly version:
#
# $ ./install_neovim.sh --nightly


################################
#
# frequently updated values

# https://github.com/neovim/neovim/releases
NVIM_VERSION="v0.8.0"	# XXX - edit for other versions


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


TMP_DIR=/tmp/nvim

function prep {
    # install needed packages
    if [ -x /usr/bin/apt-get ]; then
	sudo apt-get install -y ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip
    elif [ -x /usr/bin/pacman ]; then
	sudo pacman -Syu ninja gettext libtool autoconf automake cmake pkg-config unzip
    else
	error "* distro not supported"
    fi

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

    warn ">>> installing neovim version ${tag}..."

    unset LUA_PATH
    unset LUA_CPATH

    # clone, configure, build, and install
    git clone https://github.com/neovim/neovim.git $TMP_DIR && \
	cd $TMP_DIR && \
	git checkout ${tag} && \
	rm -rf build && \
	make clean && \
	make CMAKE_BUILD_TYPE=RelWithDebInfo && \
	sudo make install
}

# install for macOS
function install_macos {
    if [[ $1 == "--nightly" ]]; then
	brew install neovim --HEAD
    else
	brew install neovim
    fi
}

# install for linux
#
# $1: nightly or not
function install_linux {
    if [ -z $TERMUX_VERSION ]; then
	prep && install $1 && clean && update_alternatives
    else  # termux
	pkg install neovim
    fi
}

function update_alternatives {
    if [ -x /usr/bin/update-alternatives ]; then
	NVIM_BIN_PATH="/usr/local/bin/nvim" && \
	    sudo update-alternatives --install /usr/bin/vi vi $NVIM_BIN_PATH 60 && \
	    sudo update-alternatives --set vi $NVIM_BIN_PATH && \
	    sudo update-alternatives --install /usr/bin/vim vim $NVIM_BIN_PATH 60 && \
	    sudo update-alternatives --set vim $NVIM_BIN_PATH && \
	    sudo update-alternatives --install /usr/bin/editor editor $NVIM_BIN_PATH 60 && \
	    sudo update-alternatives --set editor $NVIM_BIN_PATH
    fi
}

case "$OSTYPE" in
    darwin*) install_macos $1 ;;
    linux*) install_linux $1 ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

